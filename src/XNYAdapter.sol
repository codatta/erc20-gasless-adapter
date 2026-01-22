// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {GaslessAdapterBase} from "./GaslessAdapterBase.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract XNYAdapter is GaslessAdapterBase, Ownable, Pausable {
    address public realToken;

    constructor(string memory tokenName, string memory tokenVersion, address _realToken, address initialOwner)
        GaslessAdapterBase(tokenName, tokenVersion)
        Ownable(initialOwner)
    {
        require(_realToken != address(0), "XNYAdapter: realToken cannot be the zero address");
        require(initialOwner != address(0), "XNYAdapter: initialOwner cannot be the zero address");
        realToken = _realToken;
    }

    /**
     * @dev Returns the underlying token address
     */
    function _getUnderlyingToken() internal view override returns (address) {
        return realToken;
    }

    /**
     * @dev Hook to check if transfers should be paused
     */
    function _requireNotPaused() internal view override(GaslessAdapterBase, Pausable) {
        // Use Pausable's _requireNotPaused
        super._requireNotPaused();
    }

    /**
     * @notice Pause the contract, disabling transfer operations
     * @dev Only the owner can call this function
     *      After pausing, transfer, _transfer, transferWithAuthorization and receiveWithAuthorization functions will be unavailable
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract, enabling transfer operations
     * @dev Only the owner can call this function
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
