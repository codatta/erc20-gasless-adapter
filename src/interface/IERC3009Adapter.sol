// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IERC3009} from "./IERC3009.sol";

interface IERC3009Adapter is IERC3009 {
    function underlyingToken() external view returns (address);
}