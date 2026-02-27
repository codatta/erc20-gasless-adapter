// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC3009} from "./ERC3009.sol";
import {ERC2612} from "./ERC2612.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC3009Adapter} from "./interface/IERC3009Adapter.sol";

/**
 * @title GaslessAdapterBase
 * @notice Generic base contract that adds ERC3009 and ERC2612 capability on top of any standard ERC20.
 * @dev
 * - This contract exposes a full ERC20 + ERC20Metadata interface to integrators.
 * - It wires in ERC2612 (permit) and ERC3009 (gasless transfer) using a shared EIP712 domain.
 * - The actual token balance and totalSupply are always read from an underlying ERC20.
 *
 * To integrate a new ERC20:
 * - Deploy a small adapter contract that inherits {GaslessAdapterBase}.
 * - Implement `_getUnderlyingToken()` to return the underlying ERC20 address.
 * - Optionally override `_requireNotPaused()` (e.g. by inheriting {Pausable}) to add pause control.
 *
 * Subclasses must implement: transfer, transferFrom, balanceOf, totalSupply, name, symbol, decimals, _transfer
 */
abstract contract GaslessAdapterBase is EIP712, ERC3009, ERC2612, IERC20Metadata, IERC3009Adapter {
    using SafeERC20 for IERC20;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error UnderlyingInsufficientAllowance(address owner, uint256 allowance, uint256 needed);

    /**
     * @dev Get the underlying token address - must be implemented by subclasses
     */
    function _getUnderlyingToken() internal view virtual returns (address);

    /**
     * @notice Public getter for the underlying token address.
     * @return The address of the underlying ERC20 token.
     */
    function underlyingToken() external view virtual returns (address) {
        return _getUnderlyingToken();
    }

    /**
     * @dev Hook to check if transfers should be paused - can be overridden by subclasses
     */
    function _requireNotPaused() internal view virtual {}

    /**
     * @dev Constructor that initializes EIP712 for both ERC3009 and ERC2612
     * @param tokenName EIP712 domain name
     * @param tokenVersion EIP712 domain version
     */
    constructor(string memory tokenName, string memory tokenVersion) EIP712(tokenName, tokenVersion) {}

    /**
     * @notice Standard ERC20 approve function
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Standard ERC20 allowance function
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Internal approve function - standard ERC20 implementation
     */
    function _approve(address owner, address spender, uint256 value) internal override(ERC2612) {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice Internal function to spend allowance - standard ERC20 implementation
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }

    /**
     * @dev Implements _hashTypedDataV4 for both ERC3009 and ERC2612
     */
    function _hashTypedDataV4(bytes32 structHash)
        internal
        view
        virtual
        override(EIP712, ERC3009, ERC2612)
        returns (bytes32)
    {
        return EIP712._hashTypedDataV4(structHash);
    }

    /**
     * @notice EIP712 domain separator
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    // ============ IERC20 interface implementation ============

    /**
     * @notice Transfer tokens from caller to recipient
     * @dev Transfers underlying token using transferFrom, requires approval
     */
    function transfer(address to, uint256 amount) external virtual returns (bool) {
        _requireNotPaused();
        address underlying = _getUnderlyingToken();
        uint256 allowanceUnderlying = IERC20(underlying).allowance(msg.sender, address(this));
        if (allowanceUnderlying < amount) {
            revert UnderlyingInsufficientAllowance(msg.sender, allowanceUnderlying, amount);
        }

        IERC20(underlying).safeTransferFrom(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another
     * @dev Standard implementation that uses _transfer and _spendAllowance
     */
    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        address spender = msg.sender;
        // If called internally (e.g., from transferWithAuthorization), skip allowance check
        if (spender != address(this)) {
            _spendAllowance(from, spender, amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @notice Get balance of an account from underlying token
     */
    function balanceOf(address account) external view virtual returns (uint256) {
        return IERC20(_getUnderlyingToken()).balanceOf(account);
    }

    /**
     * @notice Get total supply from underlying token
     */
    function totalSupply() external view virtual returns (uint256) {
        return IERC20(_getUnderlyingToken()).totalSupply();
    }

    // ============ IERC20Metadata interface implementation ============

    /**
     * @notice Get token name - "Wrapper {underlying name}"
     */
    function name() external view virtual returns (string memory) {
        return string.concat("Wrapper ", IERC20Metadata(_getUnderlyingToken()).name());
    }

    /**
     * @notice Get token symbol - "W{underlying symbol}"
     */
    function symbol() external view virtual returns (string memory) {
        return string.concat("W", IERC20Metadata(_getUnderlyingToken()).symbol());
    }

    /**
     * @notice Get token decimals from underlying token
     */
    function decimals() external view virtual returns (uint8) {
        return IERC20Metadata(_getUnderlyingToken()).decimals();
    }

    /**
     * @notice Internal transfer implementation - must check underlying token allowance
     */
    function _transfer(address from, address to, uint256 value) internal virtual override(ERC3009) {
        _requireNotPaused();
        address underlying = _getUnderlyingToken();
        uint256 allowanceUnderlying = IERC20(underlying).allowance(from, address(this));
        if (allowanceUnderlying < value) {
            revert UnderlyingInsufficientAllowance(from, allowanceUnderlying, value);
        }

        IERC20(underlying).safeTransferFrom(from, to, value);
    }
}

