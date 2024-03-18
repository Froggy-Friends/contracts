// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DefaultOperatorFiltererUpgradeable} from
    "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ONFT721Upgradeable} from
    "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/ONFT721Upgradeable.sol";
import {IONFT721Upgradeable} from
    "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/IONFT721Upgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
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
    ITadpole public constant tadpole = ITadpole(0xeCd48F326e70388D993694De59B4542cE8aF7649);
    address public constant tadpoleSender = 0x6b01aD68aB6F53128B7A6Fe7E199B31179A4629a;

    mapping(address => HibernationStatus) public hibernationStatus; // owner  => HibernationStatus
    mapping(address => uint256) public hibernationDate; // owner => block.timestamp(now)
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
        address indexed _holder, uint256 indexed _hibernateDate, HibernationStatus indexed _HibernationStatus
    );
    event Wake(address indexed _holder, uint256 indexed _wakeDate, uint256 indexed _tadpoleAmount);

    function initialize(uint256 _minGasToTransfer, address _lzEndpoint) public initializer {
        __ONFT721Upgradeable_init("Froggy Friends", "FROGGY", _minGasToTransfer, _lzEndpoint);
        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ERC2981_init();

        froggyUrl = "https://metadata.froggyfriendsnft.com/";
        maxSupply = 4444;
    }

    function totalSupply() public view returns (uint256) {
        return _totalMinted;
    }

    function setFroggyUrl(string memory _froggyUrl) external onlyOwner {
        froggyUrl = _froggyUrl;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert InvalidToken();
        return string(abi.encodePacked(froggyUrl, StringsUpgradeable.toString(tokenId)));
    }

    function setRoyalties(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // =============================================================
    //                      ERC2981 OVERRIDES
    // =============================================================

    function approve(address operator, uint256 tokenId)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
        ifNotHibernating(tokenId)
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
        ifNotHibernating(tokenId)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
        ifNotHibernating(tokenId)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981Upgradeable, ONFT721Upgradeable)
        returns (bool)
    {
        return (
            interfaceId == type(IERC2981Upgradeable).interfaceId || interfaceId == type(IONFT721Upgradeable).interfaceId
                || super.supportsInterface(interfaceId)
        );
    }

    // =============================================================
    //                      HIBERNATION
    // =============================================================

    modifier ifNotHibernating(uint256 _tokenId) {
        if (hibernationStatus[ownerOf(_tokenId)] != HibernationStatus.AWAKE) revert InvalidHibernationStatus();
        _;
    }

    modifier checkHibernationIsAvailable(HibernationStatus _hibernationStatus) {
        if (!hibernationAvailable[_hibernationStatus]) revert InvalidHibernationStatus();
        _;
    }

    /**
     * Hibernates for the chosen amount of time
     * @param _hibernationStatus 1 = 30 days, 2 = 60 days, 3 = 90 days
     */
    function hibernate(HibernationStatus _hibernationStatus) external checkHibernationIsAvailable(_hibernationStatus) {
        if (balanceOf(msg.sender) == 0 || hibernationDate[msg.sender] > 0) revert InvalidSize();
        hibernationStatus[msg.sender] = _hibernationStatus;
        hibernationDate[msg.sender] = block.timestamp;
        emit Hibernate(msg.sender, block.timestamp, _hibernationStatus);
    }

    /**
     * Wakes frogs from hibernation and distributes tadpole rewards to holder
     */
    function wake(bytes32[][] memory _proofs) external {
        if (hibernationDate[msg.sender] == 0) revert InvalidHibernationStatus();
        if (getUnlockTimestamp(msg.sender) > block.timestamp) revert HibernationIncomplete();
        if (_proofs.length > 3) revert InvalidSize();
        uint256 totalTadpoleAmount_ = _calculateRewardPerFroggy(_proofs) * balanceOf(msg.sender);
        tadpole.transfer(msg.sender, totalTadpoleAmount_);
        hibernationStatus[msg.sender] = HibernationStatus.AWAKE;
        emit Wake(msg.sender, block.timestamp, totalTadpoleAmount_);
    }

    /**
     * Returns the unlock date to wake frogs from hibernation for a holder
     * @param _holder address of holder to query
     * @return unlockTimestamp hibernation completion date in seconds
     */
    function getUnlockTimestamp(address _holder) public view returns (uint256) {
        return hibernationDate[_holder] + (uint256(hibernationStatus[_holder]) * 30 days);
    }

    /**
     * Calculates total rewards for hibernation chosen by holder per Froggy.
     * Reward is number of frogs owned multiplied by the duration rate and boosts
     * @param _proofs merkle proofs array for boost ownership
     */
    function _calculateRewardPerFroggy(bytes32[][] memory _proofs) private view returns (uint256) {
        uint256 hibernationTadpole_ = hibernationStatusRate[hibernationStatus[msg.sender]];
        uint256 totalBoost_;
        for (uint256 index = 0; index < _proofs.length; index++) {
            if (_proofs[index].length > 0 && _verifyProof(_proofs[index], roots[Boost(index)], msg.sender)) {
                totalBoost_ += boostRate[Boost(index)];
            }
        }

        return hibernationTadpole_ + ((hibernationTadpole_ * totalBoost_) / 100); // hibernationTadpole_ + totalBoostedTadpoles_
    }

    function _verifyProof(bytes32[] memory _proof, bytes32 _root, address _holder) private pure returns (bool) {
        return MerkleProofUpgradeable.verify(_proof, _root, keccak256(abi.encodePacked(_holder)));
    }

    /**
     * Sets the hibernation duration rate
     * Amount is passed as 16 decimal number and saved as 18 decimal number
     * @param _status the hibernation duration i.e. 1 = 30 days, 2 = 60 days, 3 = 90 days
     * @param _amount the tadpole base rate in 16 decimails i.e. for 0.1$ TADPOLE pass the value 1000000000000000
     */
    function setTadpoleReward(HibernationStatus _status, uint256 _amount) external onlyOwner {
        hibernationStatusRate[_status] = _amount * 100;
    }

    /**
     * Sets the boost rate and root
     * @param _boost the boost enum value
     * @param _rate the boost rate flat number i.e. for 10% pass the value 10
     * @param _root the boost merkle root
     */
    function setBoost(Boost _boost, uint256 _rate, bytes32 _root) external onlyOwner {
        boostRate[_boost] = _rate;
        roots[_boost] = _root;
    }

    /**
     * Enable or disable all hibernation duration options
     * @param _thirdyDayAvailable set to true to enable 30 day hibernation, false to disable the option
     * @param _sixtyDayAvailable set to true to enable 60 day hibernation, false to disable the option
     * @param _ninetyDayAvailable set to true to enable 90 day hibernation, false to disable the option
     */
    function setHibernationAvailable(bool _thirdyDayAvailable, bool _sixtyDayAvailable, bool _ninetyDayAvailable)
        external
        onlyOwner
    {
        hibernationAvailable[HibernationStatus.THIRTY_DAYS] = _thirdyDayAvailable;
        hibernationAvailable[HibernationStatus.SIXTY_DAYS] = _sixtyDayAvailable;
        hibernationAvailable[HibernationStatus.NINETY_DAYS] = _ninetyDayAvailable;
    }
}
