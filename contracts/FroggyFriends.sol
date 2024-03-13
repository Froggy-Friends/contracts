// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/ONFT721Upgradeable.sol";
import {IONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/IONFT721Upgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {ITadpole, IRibbitItem, IFroggySoulbounds} from "./Interfaces.sol";

error InvalidSize();
error OverMaxSupply();

contract FroggyFriends is OwnableUpgradeable, DefaultOperatorFiltererUpgradeable, ERC2981Upgradeable, ONFT721Upgradeable {
    string public froggyUrl;
    uint256 public maxSupply;
    uint256 private _totalMinted;

    // Hibernation
    ITadpole public tadpole;
    address public tadpoleSender;
    IRibbitItem public ribbitItem;
    IFroggySoulbounds public froggySoulbounds;
    mapping(uint8 => bytes32) roots; // boost merkle roots
    mapping(address => HibernationStatus) public hibernationStatus; // owner  => HibernationStatus
    mapping(address => uint256) public hibernationDate; // owner => block.timestamp(now)
    mapping(HibernationStatus => uint256) public hibernationStatusRate; // HibernationStatus => tadpole amount per frog
    mapping(address => mapping(uint256 => uint256)) public boostRate; // tokenAddress => tokenId => rate
    mapping(HibernationStatus => bool) public hibernationAvailable; // HibernationStatus => isAvailable
    enum HibernationStatus { AWAKE, THIRTYDAY, SIXTYDAY, NINETYDAY }
    // Events
    event Hibernate(address indexed _owner, uint256 indexed _lockDate, HibernationStatus indexed _HibernationStatus);
    event Wake(address indexed _owner, uint256 indexed _lockDate, uint256 indexed _tadpoleAmount);
    
    function initialize(uint256 _minGasToTransfer, address _lzEndpoint) initializer public {
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
        return bytes(froggyUrl).length > 0 ? string(abi.encodePacked(froggyUrl, StringsUpgradeable.toString(tokenId))) : "";
    }

    function setRoyalties(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // =============================================================
    //                      ERC2981 OVERRIDES
    // =============================================================

    function approve(address operator, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }
       
    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981Upgradeable,ONFT721Upgradeable) returns (bool) {
        return (
            interfaceId == type(IERC2981Upgradeable).interfaceId || 
            interfaceId == type(IONFT721Upgradeable).interfaceId || 
            super.supportsInterface(interfaceId)
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
    function hibernate(HibernationStatus _hibernationStatus) public checkHibernationIsAvailable(_hibernationStatus) returns (bool) {
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
        require(block.timestamp > getUnlockTimestamp(msg.sender), "Your Hibernation period has not ended.");
        uint256 _tadpoleAmount = _calculateTotalRewardAmount(_proofs); // calculate total reward amount includes base rate + boosts
        tadpole.transferFrom(tadpoleSender, msg.sender, _tadpoleAmount);
        hibernationStatus[msg.sender] = HibernationStatus.AWAKE;
        emit Wake(msg.sender, block.timestamp, _tadpoleAmount);
        return true;
    }

    /**
     * @param _account address of holder to query
     * @return lockDuration total hibernation duration in seconds
     */
    function getLockDuration(address _account) public view returns (uint256) {
        return (uint8(hibernationStatus[_account]) * 30) * (24 * 60 * 60); // (number of hibernate days) * each day
    }

    /**
     * @param _account address of holder to query
     * @return unlockTimestamp hibernation completion date in seconds
     */
    function getUnlockTimestamp(address _account) public view returns (uint256) {
        return getLockDuration(_account) + hibernationDate[_account];
    }

    /**
     * Calculates total rewards including all frogs held * (base rate + boosts)
     */
    function _calculateTotalRewardAmount(bytes32[][] memory _proofs) internal view returns (uint256) {
        return _getRewardPerFroggy(_proofs) * balanceOf(msg.sender);
    }

    /**
     * Calculates tadpole rewards per frog including (base rate + boosts)
     */
    function _getRewardPerFroggy(bytes32[][] memory _proofs) internal view returns (uint256) {
        return (hibernationStatusRate[hibernationStatus[msg.sender]]) + _calculateTotalBoostedTadpoles(_proofs);
    }

    /**
     * Calculates total tadpole boost including (hibernation duration rate * boost) / 100.
     * The hibernation duration (30,60,90) rate should be a flat number.
     */
    function _calculateTotalBoostedTadpoles(bytes32[][] memory _proofs) internal view returns (uint256) {
        return (hibernationStatusRate[hibernationStatus[msg.sender]] * _calculateTotalBoost(_proofs)) / 100;
    }

    /**
     * Calculates total boost percentage for the holder by adding all available boost percentages.
     * Boost number mapping
     * 0 = Golden Lily Pad
     * 1 = Froggy Minter SBT
     * 2 = One Year Anniversary SBT
     */
    function _calculateTotalBoost(bytes32[][] memory _proofs) internal view returns (uint256) {
        require(_proofs.length == 3, "Must supply all boost proofs");
        uint256 boost;

        if (_verifyProof(_proofs[0], roots[0])) boost += boostRate[address(ribbitItem)][1]; // Golden Lily Pad
        if (_verifyProof(_proofs[1], roots[1])) boost += boostRate[address(froggySoulbounds)][1]; // Froggy Minter SBT
        if (_verifyProof(_proofs[2], roots[2])) boost += boostRate[address(froggySoulbounds)][2]; // Froggy One Year Holder SBT
        
        return boost;
    }

    function _verifyProof(bytes32[] memory _proof, bytes32 _root) internal view returns (bool) {
        return MerkleProofUpgradeable.verify(_proof, _root, keccak256(abi.encodePacked(msg.sender)));
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
     * Sets the boost rate
     * @param _contract the boost contract address
     * @param _tokenId the boost token id
     * @param _rate the boost rate flat number i.e. set 10 for 10% representation
     */
    function setBoostRate(address _contract, uint256 _tokenId, uint256 _rate) public onlyOwner {
        // argument "_rate" should not be in percentage.
        // example: for 10%  the argument for "_rate" should be 10
        boostRate[_contract][_tokenId] = _rate;
    }

    /**
     * Enable or disable all hibernation duration options
     * @param _thirdyDayAvailable set to true to enable 30 day hibernation, false to disable the option
     * @param _sixtyDayAvailable set to true to enable 60 day hibernation, false to disable the option
     * @param _ninetyDayAvailable set to true to enable 90 day hibernation, false to disable the option
     */
    function setHibernationAvailable(bool _thirdyDayAvailable, bool _sixtyDayAvailable, bool _ninetyDayAvailable) public onlyOwner {
        hibernationAvailable[HibernationStatus.THIRTYDAY] = _thirdyDayAvailable;
        hibernationAvailable[HibernationStatus.SIXTYDAY] = _sixtyDayAvailable;
        hibernationAvailable[HibernationStatus.NINETYDAY] = _ninetyDayAvailable;
    }

    /**
     * Sets the external contract addresses
     * @param _ribbitItem the contract address of the ribbit items collection
     * @param _froggySoulbounds the contract address of the froggy soulbounds collection
     * @param _tadpole the contract address of the tadpoles collection
     * @param _sender address holding tadpole rewards
     */
    function setExternalAddress(address _ribbitItem, address _froggySoulbounds, address _tadpole, address _sender) public onlyOwner {
        ribbitItem = IRibbitItem(_ribbitItem);
        froggySoulbounds = IFroggySoulbounds(_froggySoulbounds);
        tadpole = ITadpole(_tadpole);
        tadpoleSender = _sender;
    }

    /**
     * Sets merkle roots for boost holders
     * Boost number mapping (boost ids should match ids in roots map)
     * 0 = Golden Lily Pad
     * 1 = Froggy Minter SBT
     * 2 = One Year Anniversary SBT
     * @param _boostId the boost number
     * @param _root the boost merkle root
     */
    function setBoostRoot(uint8 _boostId, bytes32 _root) public onlyOwner {
        roots[_boostId] = _root;
    }
}