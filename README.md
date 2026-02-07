## Gasless Adapter for Any ERC20

This repository provides a **generic Gasless Adapter module** that adds
ERC2612 (`permit`) and ERC3009 (gasless transfers) support to any
standard ERC20 token.

- **Core base contract**: `GaslessAdapterBase`
- **Standard adapter implementation**: `StandardGaslessAdapter` (deployed via factory)
- **Factory contract**: `GaslessAdapterFactory` (deploys adapters)
- **Standalone extensions**: `ERC2612`, `ERC3009`

The design follows EIP-712 and exposes a full ERC20 interface plus:

- **ERC2612**: `permit`, `nonces`, `DOMAIN_SEPARATOR`
- **ERC3009**: `transferWithAuthorization`, `receiveWithAuthorization`,
  `cancelAuthorization`, `authorizationState`

## Quick Start: Deploy via Factory

Deploy a gasless adapter for your ERC20 using the provided Foundry scripts.

### Supported Networks

Currently the repository ships with a pre-deployed factory on:

- **Base Sepolia**
  - **Chain ID**: `84532`
  - **Factory address**: `0x5e5E52fb594e5F98BD582b309d16FAE02D1e9032`

You can deploy additional factories on other networks if needed.

### 1. Deploy an Adapter via Factory (Foundry)

Use the `DeployAdapterViaFactory` script. Required environment variables:

- `PRIVATE_KEY`: Deployer private key
- `RPC_URL`: RPC endpoint for the target network
- `FACTORY_ADDRESS`: Factory contract address (see above)
- `UNDERLYING_TOKEN`: Underlying ERC20 token address
- `TOKEN_NAME`: EIP712 domain name
- `TOKEN_VERSION`: EIP712 domain version
- `OWNER`: Owner address for the adapter

Example (Base Sepolia):

```shell
export PRIVATE_KEY=your-private-key
export RPC_URL=https://sepolia.base.org
export FACTORY_ADDRESS=0x5e5E52fb594e5F98BD582b309d16FAE02D1e9032
export UNDERLYING_TOKEN=0x...        # your ERC20 token
export TOKEN_NAME="MyToken Adapter"
export TOKEN_VERSION="1"
export OWNER=0x...                   # adapter owner

forge script script/DeployAdapterViaFactory.s.sol:DeployAdapterViaFactory \
  --rpc-url $RPC_URL \
  --broadcast
```

The script will print the deployed adapter address to the console.

If you prefer to deploy the factory yourself on another network, use:

```shell
export PRIVATE_KEY=your-private-key
export RPC_URL=<your-rpc-url>

forge script script/GaslessAdapterFactory.s.sol:GaslessAdapterFactoryDeploy \
  --rpc-url $RPC_URL \
  --broadcast
```

Then pass the new factory address as `FACTORY_ADDRESS` when running `DeployAdapterViaFactory`.

## Integrating Your ERC20 with the Adapter

You can integrate in two ways:

1. **Use Factory + SDK** - Deploy via factory.
2. **Write your own adapter contract that inherits `GaslessAdapterBase`** - For custom logic.

### 1. Writing Your Own Adapter on `GaslessAdapterBase`

If you need custom logic, inherit `GaslessAdapterBase` directly:

- Implement `_getUnderlyingToken()` to return the underlying ERC20 address.
- Optionally:
  - inherit `Pausable` and override `_requireNotPaused()` to enforce pause,
  - inherit `Ownable` or `AccessControl` to restrict admin operations.

The signature verification and allowance handling for ERC2612/3009 are already
implemented in `GaslessAdapterBase`, `ERC2612`, and `ERC3009`.

## EIP-712 Configuration

The EIP-712 domain is configured through the `GaslessAdapterBase` constructor:

- `tokenName`: used as the domain `name`.
- `tokenVersion`: used as the domain `version`.

Frontends and wallets must use these values when constructing EIP-712 payloads
for:

- ERC2612 `Permit`:
  - Type hash:
    `Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)`
- ERC3009 transfers:
  - `TransferWithAuthorization`
  - `ReceiveWithAuthorization`
  - `CancelAuthorization`

Use the adapter’s `DOMAIN_SEPARATOR()` and `nonces(owner)` view functions when
building client-side signing payloads.

## Foundry Commands

This repository uses Foundry for building and testing.

- **Build**

```shell
forge build
```

- **Test**

```shell
forge test
```

- **Format**

```shell
forge fmt
```

- **Gas Snapshots**

```shell
forge snapshot
```

- **Anvil**

```shell
anvil
```
