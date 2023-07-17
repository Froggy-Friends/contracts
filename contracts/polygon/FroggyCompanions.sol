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
error MintArrayMismatch();
error MintSupplyReached();
error CreateOutOfBounds();

contract FroggyCompanions is ONFT1155Upgradeable, ERC2981Upgradeable, DefaultOperatorFiltererUpgradeable {
    mapping (address => bool) public approvedAccounts;
    mapping (uint256 => uint256) public mintedSupply;
    mapping (uint256 => uint256) public maxSupply;
    mapping (uint256 => Companion) public companions;
    string private contractUrl;
    uint256 public totalSupply;

    struct Companion {
        string name;
        uint256 price;
        uint256 supply;
    }

    function initialize(string calldata _baseUrl, string calldata _contractUrl, address _lzEndpoint) initializer public {
        __ONFT1155Upgradeable_init(_baseUrl, _lzEndpoint);
        contractUrl = _contractUrl;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981Upgradeable, ONFT1155Upgradeable) returns (bool) {
        return (
            interfaceId == type(IERC2981Upgradeable).interfaceId || 
            interfaceId == type(IONFT1155Upgradeable).interfaceId || 
            super.supportsInterface(interfaceId)
        );
    }

}