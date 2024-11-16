// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 
error TooManyChildren(address voter, uint256 childCount);
error DagConsistencyCheckFailed(uint256 failCase, address voter, address recipient, uint256 i);
