// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ITadpole {
    function transferFrom(address from, address to, uint256 amountOrId) external;
}

// address : 0x1f6A5CF9366F968C205467BD7a9f382b3454dFB3
interface IRibbitItem {
    /// @notice returns the number of ribbit items an account owns
    /// @param account the address to check the balance of
    /// @param id the ribbit item id
    //note: Golden Lily Pad Token ID = 1
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

// address : 0xfdffd2208aa128a2f9dc520a2a4e93746b588209
interface IFroggySoulbounds {
    //Froggy Minter Token ID = 1
    //One Year Anniversary Holder Token ID = 2
    function balanceOf(address account, uint256 id) external view returns (uint256);
}