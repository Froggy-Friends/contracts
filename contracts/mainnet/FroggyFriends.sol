// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// import {ONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/ONFT721Upgradeable.sol";
// import {IONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/IONFT721Upgradeable.sol";
import {ITadpole} from "./Interfaces.sol";

error InvalidSize();
error InvalidToken();
error InvalidHibernationStatus();
error HibernationIncomplete();
error OutOfTadpoles();

contract FroggyFriends is
    OwnableUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    ERC2981Upgradeable,
    ONFT721Upgradeable
{
    string public froggyUrl;
    uint256 public maxSupply;
    uint256 private _totalMinted;

    // Hibernation
    ITadpole public constant tadpole =
        ITadpole(0xeCd48F326e70388D993694De59B4542cE8aF7649);

    mapping(address => HibernationStatus) public hibernationStatus; // owner  => HibernationStatus
    mapping(address => uint256) public hibernationOneDate; // owner => block.timestamp(now) for season one
    mapping(address => uint256) public hibernationTwoDate; // owner => block.timestamp(now) for season two
    mapping(HibernationStatus => uint256) public hibernationStatusRate; // HibernationStatus => tadpole amount per frog
    mapping(Boost => uint256) public boostRate; // Boost => rate
    mapping(HibernationStatus => bool) public hibernationAvailable; // HibernationStatus => isAvailable
    mapping(Boost => bytes32) roots; // boost merkle roots

    enum HibernationStatus {
        AWAKE,
        THIRTY_DAYS,
        SIXTY_DAYS,
        NINETY_DAYS
    }

    enum Boost {
        GOLDEN_LILY_PAD,
        FROGGY_MINTER_SBT,
        ONE_YEAR_ANNIVERSARY_SBT
    }

    // Events
    event Hibernate(
        address indexed _holder,
        uint256 indexed _hibernateDate,
        HibernationStatus indexed _HibernationStatus
    );
    event Wake(
        address indexed _holder,
        uint256 indexed _wakeDate,
        uint256 indexed _tadpoleAmount
    );

    function initialize(
        uint256 _minGasToTransfer,
        address _lzEndpoint
    ) public initializer {
        __ONFT721Upgradeable_init(
            "FroggyFriends",
            "FROGGY",
            _minGasToTransfer,
            _lzEndpoint
        );
        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ERC2981_init();

        froggyUrl = "https://metadata.froggyfriendsnft.com/";
        maxSupply = 4444;
    }

    function mint(uint256 tokenId) external payable {
        require(_totalMinted < 4444, "Minted out");
        _mint(msg.sender, tokenId);
        _totalMinted++;
    }

    function totalSupply() public view returns (uint256) {
        return _totalMinted;
    }

    function setFroggyUrl(string memory _froggyUrl) external onlyOwner {
        froggyUrl = _froggyUrl;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert InvalidToken();
        return
            string(
                abi.encodePacked(
                    froggyUrl,
                    Strings.toString(tokenId)
                )
            );
    }

    function setRoyalties(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // =============================================================
    //                      ERC2981 OVERRIDES
    // =============================================================

    function approve(
        address operator,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC2981Upgradeable, ONFT721Upgradeable)
        returns (bool)
    {
        return (interfaceId == type(IERC2981Upgradeable).interfaceId ||
            interfaceId == type(IONFT721Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId));
    }

    // =============================================================
    //                      HIBERNATION
    // =============================================================

    /**
     * Wakes frogs from hibernation and distributes tadpole rewards to holder
     */
    function wake(bytes32[][] memory _proofs) external {
        if (hibernationStatus[msg.sender] == HibernationStatus.AWAKE)
            revert InvalidHibernationStatus();
        if (getUnlockTimestamp(msg.sender) > block.timestamp)
            revert HibernationIncomplete();
        if (_proofs.length > 3) revert InvalidSize();
        uint256 totalTadpoleAmount_ = calculateReward(_proofs, msg.sender);
        if (totalTadpoleAmount_ > tadpole.balanceOf(address(this)))
            revert OutOfTadpoles();
        tadpole.transfer(msg.sender, totalTadpoleAmount_);
        hibernationStatus[msg.sender] = HibernationStatus.AWAKE;
        emit Wake(msg.sender, block.timestamp, totalTadpoleAmount_);
    }

    /**
     * Owner function to withdraw tadpole tokens
     */
    function withdraw(address account) public onlyOwner {
        tadpole.transfer(account, tadpole.balanceOf(address(this)));
    }

    /**
     * Returns the unlock date to wake frogs from hibernation for a holder
     * @param _holder address of holder to query
     * @return unlockTimestamp hibernation completion date in seconds
     */
    function getUnlockTimestamp(address _holder) public view returns (uint256) {
        return
            hibernationOneDate[_holder] +
            (uint256(hibernationStatus[_holder]) * 30 days);
    }

    /**
     * Calculates total rewards for hibernation chosen by holder per Froggy.
     * Reward is number of frogs owned multiplied by the duration rate and boosts
     * @param _proofs merkle proofs array for boost ownership
     */
    function calculateReward(
        bytes32[][] memory _proofs,
        address _holder
    ) public view returns (uint256) {
        uint256 hibernationTadpole_ = hibernationStatusRate[
            hibernationStatus[_holder]
        ] * balanceOf(_holder);
        uint256 totalBoost_;
        for (uint256 index = 0; index < _proofs.length; index++) {
            if (
                _proofs[index].length > 0 &&
                _verifyProof(_proofs[index], roots[Boost(index)], _holder)
            ) {
                totalBoost_ += boostRate[Boost(index)];
            }
        }

        return
            hibernationTadpole_ + ((hibernationTadpole_ * totalBoost_) / 100);
    }

    function _verifyProof(
        bytes32[] memory _proof,
        bytes32 _root,
        address _holder
    ) private pure returns (bool) {
        return
            MerkleProof.verify(
                _proof,
                _root,
                keccak256(abi.encodePacked(_holder))
            );
    }
}
