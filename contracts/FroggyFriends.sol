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

    //Note :  please set value for this variable before deploy
    ITadpole public constant tadpole = ITadpole(0xF7DB5236d5Cef9DC19B09A1B6B570993B7ceAB9f);

    //Note :  please set value for this variable before deploy
    address public constant tadpoleSender = 0x6b01aD68aB6F53128B7A6Fe7E199B31179A4629a;
    /* 
    * changed we use merkle proof we dont need address of these contracts ...read the Note above SoulBound enum
    * important note: removing or adding these state variables ARE NOT ALLOWED due to storage overriding. but we still on testnet:) 
    * if it is needed then we declare it as constant so above we should changed ITadpole and tadpoleSender to constant for 
    * mainnet and i recomend we do the same for finnal testnet deployment as the storage layout should be the same
    * for better and near to real test results
    */
    // IRibbitItem public ribbitItem;
    // IFroggySoulbounds public froggySoulbounds;
    mapping(address => HibernationStatus) public hibernationStatus; // owner  => HibernationStatus
    mapping(address => uint256) public hibernationDate; // owner => block.timestamp(now)
    mapping(HibernationStatus => uint256) public hibernationStatusRate; // HibernationStatus => tadpole amount per frog
    /* 
    * changed this mapping due to declaration of SoulBound enum 
    */
    mapping(SoulBound => uint256) public boostRate; // SoulBound => rate
    mapping(HibernationStatus => bool) public hibernationAvailable; // HibernationStatus => isAvailable
    /* 
    * changed this mapping due to declaration of SoulBound enum 
    */
    mapping(SoulBound => bytes32) roots; // boost merkle roots

    enum HibernationStatus {
        AWAKE,
        THIRTYDAY,
        SIXTYDAY,
        NINETYDAY
    }
    // Note : since we decided to use merkle proof for holder's boost tokens, for the sake of reducing gas cost, we no longer
    //call on each soulbound's contract. so we dont need the contract address and tokenId as key for boostRate mapping above
    // * 0 = Golden Lily Pad
    //  * 1 = Froggy Minter SBT
    //  * 2 = One Year Anniversary SBT

    enum SoulBound {
        GOLDENLILYPAD,
        FROGGYMINTERSBT,
        ONEYEARANNIVERSARYSBT
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
        return
            bytes(froggyUrl).length > 0 ? string(abi.encodePacked(froggyUrl, StringsUpgradeable.toString(tokenId))) : "";
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
        uint256 tadpoleAmount_ = calculateTotalRewardAmount(_proofs, msg.sender); // calculate total reward amount includes base rate + boosts
        tadpole.transferFrom(tadpoleSender, msg.sender, tadpoleAmount_);
        hibernationStatus[msg.sender] = HibernationStatus.AWAKE;
        emit Wake(msg.sender, block.timestamp, tadpoleAmount_);
        return true;
    }

    /**
     * note : for reducing codesize we better merge getLockDuration inside this function but for test
     * and maybe frontend. so i leave it the way it is
     *
     * @param _holder address of holder to query
     * @return unlockTimestamp hibernation completion date in seconds
     */
    function getUnlockTimestamp(address _holder) public view returns (uint256) {
        return getLockDuration(_holder) + hibernationDate[_holder];
    }

    /**
     * @param _holder address of holder to query
     * @return lockDuration total hibernation duration in seconds
     */
    function getLockDuration(address _holder) public view returns (uint256) {
        return (uint8(hibernationStatus[_holder]) * 30) * (24 * 60 * 60); // (number of hibernate days) * each day
    }

    /**
     * Note : I've merged the calculations functions for the sake of codesize but this does not help us with unit test
     * for unit test writing more modular way will help us to see where the bug sits.so i keep other functions only for
     * test and should be deleted for mainnet deply
     *
     * Calculates total rewards including all frogs owned and boosts
     * Calculates total boost percentage for the holder by adding all available boost percentages.
     * Boost number mapping
     * 0 = Golden Lily Pad
     * 1 = Froggy Minter SBT
     * 2 = One Year Anniversary SBT
     */
    function calculateTotalRewardAmount(bytes32[][] memory _proofs, address _holder) public view returns (uint256) {
        uint256 totalBoost_;
        if (_verifyProof(_proofs[0], roots[SoulBound.GOLDENLILYPAD], _holder)) {
            totalBoost_ += boostRate[SoulBound.GOLDENLILYPAD];
        } // Golden Lily Pad
        if (_verifyProof(_proofs[1], roots[SoulBound.FROGGYMINTERSBT], _holder)) {
            totalBoost_ += boostRate[SoulBound.FROGGYMINTERSBT];
        } // Froggy Minter SBT
        if (_verifyProof(_proofs[2], roots[SoulBound.ONEYEARANNIVERSARYSBT], _holder)) {
            totalBoost_ += boostRate[SoulBound.ONEYEARANNIVERSARYSBT];
        } // Froggy One Year Holder SBT
            //Calculates total tadpole boost including (hibernation duration rate * boost) / 100. The hibernation duration (30,60,90) rate should be a flat number.
        uint256 totalBoostedTadpoles_ = (hibernationStatusRate[hibernationStatus[_holder]] * totalBoost_) / 100;
        //Calculates tadpole rewards per frog including (base rate + boosts)
        uint256 rewardsPerFroggy_ = (hibernationStatusRate[hibernationStatus[_holder]]) + totalBoostedTadpoles_;
        return rewardsPerFroggy_ * balanceOf(_holder);
    }

    // changed : i made it public so maybe teammates needs to test the proof generating algorithm
    // for mainnet it better be private
    function _verifyProof(bytes32[] memory _proof, bytes32 _root, address _holder) public view returns (bool) {
        return MerkleProofUpgradeable.verify(_proof, _root, keccak256(abi.encodePacked(_holder)));
    }

    /**
     * Sets the hibernation duration rate
     * @param _status the hibernation duration i.e. 1 = 30 days, 2 = 60 days, 3 = 90 days
     * @param _amount the tadpole base rate for the hibernation duration
     */
    function setTadpoleReward(HibernationStatus _status, uint256 _amount) public onlyOwner {
        // argument "_amount" should be considered as 16 decimals
        // argument "_amount" should be multiplied by 10**16
        hibernationStatusRate[_status] = _amount * 100;
    }

    /**
     * changed
     * Sets the boost rate
     * @param _soulBound the soulBound enum value
     * @param _rate the boost rate flat number i.e. set 10 for 10% representation
     */
    function setBoostRate(SoulBound _soulBound, uint256 _rate) public onlyOwner {
        // argument "_rate" should not be in percentage.
        // example: for 10%  the argument for "_rate" should be 10
        boostRate[_soulBound] = _rate;
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
        hibernationAvailable[HibernationStatus.THIRTYDAY] = _thirdyDayAvailable;
        hibernationAvailable[HibernationStatus.SIXTYDAY] = _sixtyDayAvailable;
        hibernationAvailable[HibernationStatus.NINETYDAY] = _ninetyDayAvailable;
    }

    /**
     * changed
     * Sets merkle roots for boost holders
     * Boost number mapping (boost ids should match ids in roots map)
     * 0 = Golden Lily Pad
     * 1 = Froggy Minter SBT
     * 2 = One Year Anniversary SBT
     * @param _soulBound the soulBound enum value
     * @param _root the boost merkle root
     */
    function setBoostRoot(SoulBound _soulBound, bytes32 _root) public onlyOwner {
        roots[_soulBound] = _root;
    }

    ////////////////  changed these meant to be here ONLY FOR TEST ///////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    /**
     * Calculates tadpole rewards per frog including (base rate + boosts)
     * Note : only for unit test - should be removed for the mainnet deploy
     */

    function _getRewardPerFroggy(bytes32[][] memory _proofs, address _holder) public view returns (uint256) {
        return (hibernationStatusRate[hibernationStatus[_holder]]) + _calculateTotalBoostedTadpoles(_proofs, _holder);
    }

    /**
     * Calculates total tadpole boost including (hibernation duration rate * boost) / 100.
     * The hibernation duration (30,60,90) rate should be a flat number.
     * Note : only for unit test - should be removed for the mainnet deploy
     */
    function _calculateTotalBoostedTadpoles(bytes32[][] memory _proofs, address _holder)
        public
        view
        returns (uint256)
    {
        return (hibernationStatusRate[hibernationStatus[_holder]] * _calculateTotalBoost(_proofs, _holder)) / 100;
    }

    /**
     * Calculates total boost percentage for the holder by adding all available boost percentages.
     * Boost number mapping
     * 0 = Golden Lily Pad
     * 1 = Froggy Minter SBT
     * 2 = One Year Anniversary SBT
     * Note : only for unit test - should be removed for the mainnet deploy
     */
    function _calculateTotalBoost(bytes32[][] memory _proofs, address _holder) public view returns (uint256) {
        require(_proofs.length == 3, "Must supply all boost proofs");
        uint256 boost;
        // Golden Lily Pad
        if (_verifyProof(_proofs[0], roots[SoulBound.GOLDENLILYPAD], _holder)) {
            boost += boostRate[SoulBound.GOLDENLILYPAD];
        }
        // Froggy Minter SBT
        if (_verifyProof(_proofs[1], roots[SoulBound.FROGGYMINTERSBT], _holder)) {
            boost += boostRate[SoulBound.FROGGYMINTERSBT];
        }

        // Froggy One Year Holder SBT
        if (_verifyProof(_proofs[2], roots[SoulBound.ONEYEARANNIVERSARYSBT], _holder)) {
            boost += boostRate[SoulBound.ONEYEARANNIVERSARYSBT];
        }

        return boost;
    }
}
