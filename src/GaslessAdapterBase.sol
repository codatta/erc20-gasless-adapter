// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ERC3009 } from "./ERC3009.sol";
import { ERC2612 } from "./ERC2612.sol";

/**
 * @title GaslessAdapterBase
 * @notice Base contract combining ERC3009 and ERC2612 functionality
 * @dev This contract combines both gasless payment standards
 *      Subclasses must implement IERC20 functions (_transfer and _approve)
 */
abstract contract GaslessAdapterBase is EIP712, ERC3009, ERC2612 {
    /**
     * @dev Constructor that initializes EIP712 for both ERC3009 and ERC2612
     * @param tokenName EIP712 domain name
     * @param tokenVersion EIP712 domain version
     */
    constructor(
        string memory tokenName,
        string memory tokenVersion
    ) EIP712(tokenName, tokenVersion) {}


    /**
     * @notice Internal approve function - must be implemented by subclasses
     * @param owner          Token owner's address
     * @param spender       Spender's address
     * @param value         Amount to approve
     */
    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual override(ERC2612);

    function _hashTypedDataV4(bytes32 structHash)
        internal
        view
        virtual
        override(EIP712, ERC3009, ERC2612)
        returns (bytes32)
    {
        return EIP712._hashTypedDataV4(structHash);
    }

}

