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
import {ITadpole, IRibbitItem, IFroggySoulbounds} from "./Interfaces.sol";

error InvalidSize();
error OverMaxSupply();

contract FroggyFriends is OwnableUpgradeable, DefaultOperatorFiltererUpgradeable, ERC2981Upgradeable, ONFT721Upgradeable {
    using StringsUpgradeable for uint256;
    string public froggyUrl;
    uint256 public maxSupply;
    uint256 private _totalMinted;

    // Hibernation
    ITadpole public tadpole;
    address public tadpoleSender;
    IRibbitItem public ribbitItem;
    IFroggySoulbounds public froggySoulbounds;
    mapping(address => HibernationStatus) public lockStatus; // owner  => HibernationStatus
    mapping(address => uint256) public hibernationDate; // owner => block.timestamp(now)
    mapping(HibernationStatus => uint256) public statusTadpoleAmount; // HibernationStatus => tadpole amount per frog
    mapping(address => mapping(uint256 => uint256)) public boostRate; // tokenAddress => tokenId => rate
    mapping(HibernationStatus => bool) public lockStatusAvailability; // HibernationStatus => isAvailable
    enum HibernationStatus { AWAKE, THIRTYDAY, SIXTYDAY, NINETYDAY }
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
        return bytes(froggyUrl).length > 0 ? string(abi.encodePacked(froggyUrl, tokenId.toString())) : "";
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
        require(lockStatus[ownerOf(_tokenId)] == HibernationStatus.AWAKE, "Frog is currently Hibernating.");
        _;
    }

    modifier checkHibernationIsAvailable(HibernationStatus _hibernationStatus) {
        require(lockStatusAvailability[_hibernationStatus], "Not a valid Hibernation duration.");
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
        lockStatus[msg.sender] = _hibernationStatus;
        hibernationDate[msg.sender] = block.timestamp;
        emit Hibernate(msg.sender, block.timestamp, _hibernationStatus);
        return true;
    }

    /**
     * Wakes frogs from hibernation and distributes tadpole rewards to holder
     * @return true when wake is complete
     */
    function wake() public returns (bool) {
        require(hibernationDate[msg.sender] > 0, "You are not currently Hibernating.");
        require(block.timestamp > getUnlockTimestamp(msg.sender), "Your Hibernation period has not ended.");
        uint256 _tadpoleAmount = _calculateTotalRewardAmount(); // calculate total reward amount includes base rate + boosts
        tadpole.transferFrom(tadpoleSender, msg.sender, _tadpoleAmount);
        lockStatus[msg.sender] = HibernationStatus.AWAKE;
        emit Wake(msg.sender, block.timestamp, _tadpoleAmount);
        return true;
    }

    /**
     * @param _account address of holder to query
     * @return lockDuration total hibernation duration in seconds
     */
    function getLockDuration(address _account) public view returns (uint256) {
        return (uint8(lockStatus[_account]) * 30) * (24 * 60 * 60); // (number of hibernate days) * each day
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
    function _calculateTotalRewardAmount() internal view returns (uint256) {
        return _getRewardPerFroggy() * balanceOf(msg.sender);
    }

    /**
     * Calculates tadpole rewards per frog including (base rate + boosts)
     */
    function _getRewardPerFroggy() internal view returns (uint256) {
        return (statusTadpoleAmount[lockStatus[msg.sender]]) + _calculateTotalBoostedTadpoles();
    }

    /**
     * Calculates total tadpole boost including (hibernation duration rate * boost) / 100.
     * The hibernation duration (30,60,90) rate should be a flat number.
     */
    function _calculateTotalBoostedTadpoles() internal view returns (uint256) {
        return (statusTadpoleAmount[lockStatus[msg.sender]] * _calculateTotalBoost()) / 100;
    }

    /**
     * Calculates total boost percentage for the holder by adding all available boost percentages.
     */
    function _calculateTotalBoost() internal view returns (uint256) {
        uint256 ribbitItemBoost = boostRate[address(ribbitItem)][1] * ribbitItem.balanceOf(msg.sender, 1); // Golden Lily Pad
        uint256 froggyMinterBoost = boostRate[address(froggySoulbounds)][1] * froggySoulbounds.balanceOf(msg.sender, 1); //Froggy Minter Soulbound
        uint256 oneYearAnniversaryBoost = boostRate[address(froggySoulbounds)][2] * froggySoulbounds.balanceOf(msg.sender, 2); //One Year Anniversary Holder Soulbound
        return ribbitItemBoost + froggyMinterBoost + oneYearAnniversaryBoost;
    }

    /**
     * Sets the hibernation duration rate
     * @param _status the hibernation duration i.e. 1 = 30 days, 2 = 60 days, 3 = 90 days
     * @param _amount the tadpole base rate for the hibernation duration
     */
    function setTadpoleReward(HibernationStatus _status, uint256 _amount) public onlyOwner {
        // argument "_amount" should be considered as 16 decimals
        // argument "_amount" should be multiplied by 10**16
        statusTadpoleAmount[_status] = _amount * 100;
    }

    /**
     * Sets the boost rate
     * @param _address the boost contract address
     * @param _tokenId the boost token id
     * @param _rate the boost rate flat number i.e. set 10 for 10% representation
     */
    function setBoostRate(address _address, uint256 _tokenId, uint256 _rate) public onlyOwner {
        // argument "_rate" should not be in percentage.
        // example: for 10%  the argument for "_rate" should be 10
        boostRate[_address][_tokenId] = _rate;
    }

    /**
     * Enable or disable all hibernation duration options
     * @param _status set to true to enable all hibernation options, false to disable them
     */
    function setAllHibernationsAvailable(bool _status) public onlyOwner {
        lockStatusAvailability[HibernationStatus.THIRTYDAY] = _status;
        lockStatusAvailability[HibernationStatus.SIXTYDAY] = _status;
        lockStatusAvailability[HibernationStatus.NINETYDAY] = _status;
    }

    /**
     * Enable or disable the 90 day hibernation option
     * @param _status set to true to enable 90 day hibernation, false to disable the option
     */
    function setNinetydayAvailable(bool _status) public onlyOwner {
        lockStatusAvailability[HibernationStatus.NINETYDAY] = _status;
    }

    /**
     * Enable or disable the 60 day hibernation option
     * @param _status set to true to enable 60 day hibernation, false to disable the option
     */
    function setSixtydayAvailable(bool _status) public onlyOwner {
        lockStatusAvailability[HibernationStatus.SIXTYDAY] = _status;
    }

    /**
     * Enable or disable the 30 day hibernation option
     * @param _status set to true to enable 30 day hibernation, false to disable the option
     */
    function setThirtydayAvailable(bool _status) public onlyOwner {
        lockStatusAvailability[HibernationStatus.THIRTYDAY] = _status;
    }

    /**
     * Sets the ribbit items contract address
     * @param _ribbitItem the contract address of the ribbit items collection
     */
    function setRibbitItemContract(address _ribbitItem) public onlyOwner {
        ribbitItem = IRibbitItem(_ribbitItem);
    }

    /**
     * Sets the froggy soulbounds contract address
     * @param _froggySoulbounds the contract address of the froggy soulbounds collection
     */
    function setFroggySoulboundsContract(address _froggySoulbounds) public onlyOwner {
        froggySoulbounds = IFroggySoulbounds(_froggySoulbounds);
    }

    /**
     * Sets the tadpoles contract addresss
     * @param _tadpole the contract address of the tadpoles collection
     */
    function setTadpoleContract(address _tadpole) public onlyOwner {
        tadpole = ITadpole(_tadpole);
    }

    /**
     * Sets the address that will distribute tadpole rewards
     * The sender must approve this contract to spend tokens
     * @param _sender address holding tadpole rewards
     */
    function setTadpoleSender(address _sender) public onlyOwner {
        tadpoleSender = _sender;
    }
}