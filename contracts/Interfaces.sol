// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ITadpole {
    function transferFrom(address from, address to, uint256 amountOrId) external;
}