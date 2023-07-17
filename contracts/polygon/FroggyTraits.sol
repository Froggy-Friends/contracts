// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import {IERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol';
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ONFT1155Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC1155/ONFT1155Upgradable.sol";
import {IONFT1155Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC1155/IONFT1155Upgradeable.sol";

error UnapprovedCreator();
error UnapprovedMint();
error UnapprovedBurn();
error MintSupplyReached();
error ArraySizeMismatch();
error CreateOutOfBounds();

contract FroggyTraits is ONFT1155Upgradeable, ERC2981Upgradeable, DefaultOperatorFiltererUpgradeable {
    event TraitBurned(address indexed from, uint _tokenId, uint _amount);

    mapping (address => bool) public approvedAccounts;
    mapping (uint256 => uint256) public mintedSupply;
    mapping (uint256 => uint256) public maxSupply;
    mapping (uint256 => Trait) public traits;
    uint256 public totalSupply;

    struct Trait {
        string name;
        uint256 price;
        uint256 supply;
    }

    function initialize(string calldata _baseUrl, address _lzEndpoint) initializer public {
        __ONFT1155Upgradeable_init(_baseUrl, _lzEndpoint);
    }

    function create(uint256 _price, uint256 _supply, string calldata _name) external {
        if (approvedAccounts[msg.sender] != true) {
            revert UnapprovedCreator();
        }
        ++totalSupply;
        traits[totalSupply].name = _name;
        traits[totalSupply].price = _price;
        traits[totalSupply].supply = _supply;
    }

    function mint(address account, uint256 id, uint256 amount) public payable {
        if (approvedAccounts[msg.sender] == false) {
            revert UnapprovedMint();
        }

        if (mintedSupply[id] + amount > maxSupply[id]) {
            revert MintSupplyReached();
        }

        _mint(account, id, amount, "");
        mintedSupply[id] += amount;
    }

    function mint(address account, uint256[] calldata ids, uint256[] calldata amounts) public payable {
        if (ids.length != amounts.length) {
            revert ArraySizeMismatch();
        }

        for (uint16 i; i < ids.length;) {
            mint(account, ids[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function airdrop(address account, uint256 id, uint256 amount) external onlyOwner {
        mint(account, id, amount);
    }

    function airdrop(address account, uint256[] calldata ids, uint256[] calldata amounts) external onlyOwner {
        mint(account, ids, amounts);
    }

    /**
     * @notice burns the froggy trait by id and account
     * @param id trait id to burn
     * @param account address of trait to burn
     * @dev native ERC1155 _burn function does 'approved to burn' check
     */
    function burn(address account, uint256 id, uint256 amount) external {
        if (approvedAccounts[msg.sender] == false) {
            revert UnapprovedBurn();
        }
        _burn(account, id, amount);
        emit TraitBurned(account, id, amount);
    }

    function burn(address account, uint256[] calldata ids, uint256[] calldata amounts) external {
        if (approvedAccounts[msg.sender] == false) {
            revert UnapprovedBurn();
        }

        if (ids.length != amounts.length) {
            revert ArraySizeMismatch();
        }

        for (uint16 i; i < ids.length;) {
            _burn(account, ids[i], amounts[i]);
            emit TraitBurned(account, ids[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function approveContract(address account, bool approved) external onlyOwner {
        approvedAccounts[account] = approved;
    }

    function details(uint256 id) external view returns (Trait memory) {
        return traits[id];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981Upgradeable, ONFT1155Upgradeable) returns (bool) {
        return (
            interfaceId == type(IERC2981Upgradeable).interfaceId || 
            interfaceId == type(IONFT1155Upgradeable).interfaceId || 
            super.supportsInterface(interfaceId)
        );
    }
}