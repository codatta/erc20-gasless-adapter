// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ERC2612
 * @notice Abstract implementation of ERC-2612 Permit extension
 * @dev Inherits IERC20 but doesn't implement it - subclasses must implement IERC20 functions
 */
abstract contract ERC2612 is IERC20, IERC20Permit, Nonces {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @notice Execute a permit to set allowance via signature
     * @param owner          Token owner's address
     * @param spender       Spender's address
     * @param value         Amount to approve
     * @param deadline      Expiration time of the permit
     * @param v             v of the signature
     * @param r             r of the signature
     * @param s             s of the signature
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
    {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /**
     * @notice Internal approve function - must be implemented by subclasses
     * @param owner          Token owner's address
     * @param spender       Spender's address
     * @param value         Amount to approve
     */
    function _approve(address owner, address spender, uint256 value) internal virtual;

    /// @inheritdoc IERC20Permit
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @dev EIP-712 hash function to be provided by parent (e.g. GaslessAdapterBase)
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32);
}

