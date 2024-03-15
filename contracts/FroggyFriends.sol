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
error OverMaxSupply();

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
    event Hibernate(address indexed _owner, uint256 indexed _lockDate, HibernationStatus indexed _HibernationStatus);
    event Wake(address indexed _owner, uint256 indexed _lockDate, uint256 indexed _tadpoleAmount);

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
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
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
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
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
        require(hibernationStatus[ownerOf(_tokenId)] == HibernationStatus.AWAKE, "Frog is currently Hibernating.");
        _;
    }

    modifier checkHibernationIsAvailable(HibernationStatus _hibernationStatus) {
        require(hibernationAvailable[_hibernationStatus], "Hibernation choice is unavailable.");
        _;
    }

    /**
     * Hibernates for the chosen amount of time
     * @param _hibernationStatus 1 = 30 days, 2 = 60 days, 3 = 90 days
     * @return true when hibernation is complete
     */
    function hibernate(HibernationStatus _hibernationStatus)
        public
        checkHibernationIsAvailable(_hibernationStatus)
        returns (bool)
    {
        uint256 _balances = balanceOf(msg.sender);
        require(_balances > 0, "Frog balance is zero.");
        hibernationStatus[msg.sender] = _hibernationStatus;
        hibernationDate[msg.sender] = block.timestamp;
        emit Hibernate(msg.sender, block.timestamp, _hibernationStatus);
        return true;
    }

    /**
     * Wakes frogs from hibernation and distributes tadpole rewards to holder
     * @return true when wake is complete
     */
    function wake(bytes32[][] memory _proofs) public returns (bool) {
        require(hibernationDate[msg.sender] > 0, "Your frogs are not currently Hibernating.");
        require(block.timestamp >= getUnlockTimestamp(msg.sender), "Your Hibernation period has not ended.");
        require(_proofs.length == 3, "Must supply all boost proofs");
        uint256 tadpoleAmount_ = calculateTotalRewardAmount(_proofs, msg.sender);
        tadpole.transferFrom(tadpoleSender, msg.sender, tadpoleAmount_);
        hibernationStatus[msg.sender] = HibernationStatus.AWAKE;
        emit Wake(msg.sender, block.timestamp, tadpoleAmount_);
        return true;
    }

    /**
     * Returns the unlock date to wake frogs from hibernation for a holder
     * @param _holder address of holder to query
     * @return unlockTimestamp hibernation completion date in seconds
     */
    function getUnlockTimestamp(address _holder) public view returns (uint256) {
        uint256 lockDuration = (uint8(hibernationStatus[_holder]) * 30) * (24 * 60 * 60); // (number of hibernate days) * each day
        return lockDuration + hibernationDate[_holder];
    }

    /**
     * Calculates total rewards for hibernation chosen by holder.
     * Reward is number of frogs owned multiplied by the duration rate and boosts
     * @param _proofs merkle proofs array for boost ownership
     * @param _holder holder address
     */
    function calculateTotalRewardAmount(bytes32[][] memory _proofs, address _holder) public view returns (uint256) {
        uint256 totalBoost_;
        if (verifyProof(_proofs[0], roots[Boost.GOLDEN_LILY_PAD], _holder)) {
            totalBoost_ += boostRate[Boost.GOLDEN_LILY_PAD];
        }
        if (verifyProof(_proofs[1], roots[Boost.FROGGY_MINTER_SBT], _holder)) {
            totalBoost_ += boostRate[Boost.FROGGY_MINTER_SBT];
        } 
        if (verifyProof(_proofs[2], roots[Boost.ONE_YEAR_ANNIVERSARY_SBT], _holder)) {
            totalBoost_ += boostRate[Boost.ONE_YEAR_ANNIVERSARY_SBT];
        }
        uint256 totalBoostedTadpoles_ = (hibernationStatusRate[hibernationStatus[_holder]] * totalBoost_) / 100;
        uint256 rewardsPerFroggy_ = (hibernationStatusRate[hibernationStatus[_holder]]) + totalBoostedTadpoles_;
        return rewardsPerFroggy_ * balanceOf(_holder);
    }

    function verifyProof(bytes32[] memory _proof, bytes32 _root, address _holder) public pure returns (bool) {
        return MerkleProofUpgradeable.verify(_proof, _root, keccak256(abi.encodePacked(_holder)));
    }

    /**
     * Sets the hibernation duration rate
     * Amount is passed as 16 decimal number and saved as 18 decimal number
     * @param _status the hibernation duration i.e. 1 = 30 days, 2 = 60 days, 3 = 90 days
     * @param _amount the tadpole base rate in 16 decimails i.e. for 0.1$ TADPOLE pass the value 1000000000000000
     */
    function setTadpoleReward(HibernationStatus _status, uint256 _amount) public onlyOwner {
        hibernationStatusRate[_status] = _amount * 100;
    }

    /**
     * Sets the boost rate
     * @param _boost the boost enum value
     * @param _rate the boost rate flat number i.e. for 10% pass the value 10
     */
    function setBoostRate(Boost _boost, uint256 _rate) public onlyOwner {
        boostRate[_boost] = _rate;
    }

    /**
     * Enable or disable all hibernation duration options
     * @param _thirdyDayAvailable set to true to enable 30 day hibernation, false to disable the option
     * @param _sixtyDayAvailable set to true to enable 60 day hibernation, false to disable the option
     * @param _ninetyDayAvailable set to true to enable 90 day hibernation, false to disable the option
     */
    function setHibernationAvailable(bool _thirdyDayAvailable, bool _sixtyDayAvailable, bool _ninetyDayAvailable)
        public
        onlyOwner
    {
        hibernationAvailable[HibernationStatus.THIRTY_DAYS] = _thirdyDayAvailable;
        hibernationAvailable[HibernationStatus.SIXTY_DAYS] = _sixtyDayAvailable;
        hibernationAvailable[HibernationStatus.NINETY_DAYS] = _ninetyDayAvailable;
    }

    /**
     * changed
     * Sets merkle root for boost
     * @param _boost the Boost enum value
     * @param _root the boost merkle root
     */
    function setBoostRoot(Boost _boost, bytes32 _root) public onlyOwner {
        roots[_boost] = _root;
    }
}
