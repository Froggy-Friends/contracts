// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ITadpole {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address user) external view returns (uint256);
}