// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/ONFT721Upgradeable.sol";
import {IONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/IONFT721Upgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {ITadpole} from "./Interfaces.sol";

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

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    froggyUrl,
                    StringsUpgradeable.toString(tokenId)
                )
            );
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
        return super.supportsInterface(interfaceId);
    }
}
