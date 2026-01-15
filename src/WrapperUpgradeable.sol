// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EIP3009Upgradeable} from "./EIP3009Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WrapperUpgradeable is 
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP3009Upgradeable, 
    IERC20Permit, 
    NoncesUpgradeable, 
    IERC20Metadata 
{
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数（在代理部署时调用）
     * @param tokenName EIP712 域名名称
     * @param tokenVersion EIP712 域名版本
     * @param _realToken 底层代币地址
     * @param initialOwner 合约所有者地址（用于控制升级权限）
     */
    function initialize(
        string memory tokenName,
        string memory tokenVersion,
        address _realToken,
        address initialOwner
    ) public initializer {
        require(
            _realToken != address(0),
            "ERC20X402Wrapper: realToken cannot be the zero address"
        );
        require(
            initialOwner != address(0),
            "ERC20X402Wrapper: initialOwner cannot be the zero address"
        );
        
        // 初始化所有可升级的基类合约
        __Ownable_init(initialOwner);
        __Pausable_init();
        __EIP712_init(tokenName, tokenVersion);
        __Nonces_init();
        
        realToken = _realToken;
    }

    /**
     * @dev 授权升级函数，只有所有者可以升级合约
     * @param newImplementation 新的实现合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
    ) public view virtual override(IERC20Permit, NoncesUpgradeable) returns (uint256) {
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
     *      暂停后，transfer 和 _transfer 函数将不可用
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
