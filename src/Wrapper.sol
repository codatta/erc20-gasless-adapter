// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EIP3009} from "./EIP3009.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Wrapper is EIP3009, Ownable, Pausable, IERC20Permit, Nonces, IERC20Metadata {
    using SafeERC20 for IERC20;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    mapping(address account => mapping(address spender => uint256))
        private _allowances;

    address public realToken;

    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error UnderlyingInsufficientAllowance(
        address owner,
        uint256 allowance,
        uint256 needed
    );

    constructor(
        string memory tokenName,
        string memory tokenVersion,
        address _realToken,
        address initialOwner
    ) EIP712(tokenName, tokenVersion) Ownable(initialOwner) {
        require(
            _realToken != address(0),
            "ERC20X402Wrapper: realToken cannot be the zero address"
        );
        require(
            initialOwner != address(0),
            "ERC20X402Wrapper: initialOwner cannot be the zero address"
        );
        realToken = _realToken;
    }
    /**
     * @notice 转账底层 `realToken` 到 `to`
     * @dev 重要说明（非标准 ERC20 行为）：
     *      - 这里的 `transfer` 实际会调用 `realToken.transferFrom(msg.sender, to, amount)`
     *      - 因此 **调用者必须预先对 Wrapper 合约执行 `realToken.approve(address(this), amount)`**，
     *        否则会因为底层授权不足而失败
     *      - 这样设计是为了复用底层代币的余额与授权模型，并配合 EIP-3009 / Permit 流程使用
     *      - 当合约暂停时，此函数不可用
     */
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 allowanceUnderlying = IERC20(realToken).allowance(
            msg.sender,
            address(this)
        );
        if (allowanceUnderlying < amount) {
            revert UnderlyingInsufficientAllowance(
                msg.sender,
                allowanceUnderlying,
                amount
            );
        }

        IERC20(realToken).safeTransferFrom(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        uint256 allowanceUnderlying = IERC20(realToken).allowance(
            from,
            address(this)
        );
        if (allowanceUnderlying < value) {
            revert UnderlyingInsufficientAllowance(
                from,
                allowanceUnderlying,
                value
            );
        }

        IERC20(realToken).safeTransferFrom(from, to, value);
    }

    /// @dev Modifier methods that revert
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;

        emit Approval(owner, spender, value);
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function balanceOf(address account) external view returns (uint256) {
        return IERC20(realToken).balanceOf(account);
    }

    function decimals() external view returns (uint8) {
        return IERC20Metadata(realToken).decimals();
    }

    function name() external view returns (string memory) {
        //Wrapper name
        return string.concat("Wrapper ", IERC20Metadata(realToken).name());
    }

    function symbol() external view returns (string memory) {
        //Wrapper symbol
        return string.concat("W", IERC20Metadata(realToken).symbol());
    }

    function totalSupply() external view returns (uint256) {
        return IERC20(realToken).totalSupply();
    }

    /// @inheritdoc IERC20Permit
    function nonces(
        address owner
    ) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc IERC20Permit
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    function DOMAIN_SEPARATOR()
        external
        view
        override(IERC20Permit)
        returns (bytes32)
    {
        return _domainSeparatorV4();
    }

    /**
     * @notice 暂停合约，禁止转账操作
     * @dev 只有所有者可以调用此函数
     *      暂停后，transfer、_transfer、transferWithAuthorization 和 receiveWithAuthorization 函数将不可用
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice 恢复合约，允许转账操作
     * @dev 只有所有者可以调用此函数
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
