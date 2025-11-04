# Quiet Finance Protocol Contracts

## Tokens
|Token|Price|Type|
|-|-|-|
|qUSD|1 USDC|erc20 stablecoin|
|sqUSD|constantly goes up, reflects yield|erc4626 vault|

## Contracts
- `Strategy` - Contract, which represents one atomic yield source (example: we deposit USDC to Aave Ethereum and get lending yield - it's strategy, USDT Ethereum deposit or USDC Base deposit it's another strategies).
- `LiquidityNode` - Do only one thing: liquidity management. In Quiet Finance ther are multiple instances of this contract will be deployed - for every chain and every token (example: contract for USDT on ethereum, contract for USDC on Base).
- `LiquidityEdge` - Contract, which connects two `LiquidityNode` contracts (example: contract for USDC on Ethereum <> USDC on Base via CCTP, contract for USDC on Ethereum <> USDT on Ethereum). `LiquidityEdge` doesn't holds any liquidity, its just moved it from one edge to another.
- `Gateway` - main contract for all user-ended scenarios. Containts logic for minting qUSD, instant qUSD redeem and normal qUSD redeem (via queue).

## Scenarios
### Deposit
   - User calls `Gateway.issue` to transfer USDC in and mint an equal amount of qUSD to `to`.
   - *Optionally*: User calls `sqUSD.deposit` / `sqUSD.mint` and gets erc4626 sqUSD vault.
   - __NB:__ Funds are sit at `Gateway` contract and waits for next rebalance.

### Instant redeem
- *If user have sqUSD* User calls `sqUSD.withraw` / `sqUSD.burn` and gets erc20 qUSD token.
- User calls `Gateway.redeemInstant` to burn qUSD and get USDC.
- __NB:__ Instant redeem can be done only if `Hub` have enough USDC on his balance 
- __NB 2:__ `Hub` takes fee for instant redeem and sends it to Quiet Finance treasury

### Redeem (via queue)
- *If user have sqUSD* User calls `sqUSD.withraw` / `sqUSD.burn` and gets erc20 qUSD token.
- User calls `Gateway.requestRedeem` to burn qUSD and join the withdrawal queue. `Gateway` creates redeem request for user and put it into FIFO queue.
- When USDC is prepared, __rebalancer__ calls `setMaxRedeemableId` to allow users reedem his funds.
- When user redeem request processed (eg `redeemRequest.id < maxRedeemableId`), user calls `Gateway.finishRedeem` and contracts sends him USDC.

### Rebalance
- When __rebalancer__ want to add funds to strategy, it calls `LiquidityNode.enter`
- When __rebalancer__ want to remove funds from strategy, it calls `LiquidityNode.exit`
- When __rebalancer__ want to move funds to another `LiquidityNode`, it calls `LiquidityNode.transferLiquidity`


## Accounting
All accounting in Quiet Finance conducted in USDC. `Strategy` and `LiquidityNode` implements `nav()` function, which returns amount of USDC, which sits in contract.

`Strategy` nav examples:
- USDC Ethereum AAVE nav - amount of deposited USDC
- USDT Ethereum Morpho nav - amount of deposited USDT * USDC/USDT price

`LiquidityNode` nav it is sum of all whitelisted `Strategy.nav` + unallocated asstets on balance.
```math
NAV_{LiqiudityNode} = \sum_{}{NAV_{Strategy}}
```
Fund held by `Gateway` not included to NAV.

## Access control
All Quiet Finance contracts uses [AccessManager OpenZeppelin concept](https://docs.openzeppelin.com/contracts/5.x/access-control#access-management), its allow to granular control for access to every function of system.
![AccessManager scheme](https://docs.openzeppelin.com/access-manager.svg)


## Strategy implementation
As stated above, each `Strategy` should implements one atomic yield source. To achieve it with saving universal composability, we allows pass inside functions any arbitrary data, which helps strategy decide, what it should do.

Example:
```solidity
import {Strategy} from "@quiet-finance/protocol/contracts/base/Strategy.sol";

contract Strategy {
   function _deposit(uint256 amount, bytes calldata data) internal {
      (address router, bytes memory swapDetails) = abi.decode(data, (address, bytes));
      IRouter(router).swap(swapDetails);
      ... 
   }
}
```

## Rebalance
When rebalance triggers, we do several steps:

1. We do all manipulations with liquidity
- deposit more liquidity into strategy (`LiquidityNode.enter`)
- withdraw liquidity from strategy (`LiquidityNode.exit`)
- move liquidity (`LiquidityNode.transferLiquidity`)
2. After liquidity manipluation NAV reflects all yield and losses (from rebalance fees).
3. We calculate `assetsDelta`
- If `Gateway` holds too many USDC, `assetsDelta` should be positive (we want to deposit it into strategies)
- If `Gateway` holds not enougth USDC, `assetsDelta` should be negative (we need reserves for instant withdrawal or we need process withdrawal queue)
4. We run `finishRebalance` which:
- Mints new `qUSD` to `sqUSD` balance (which reflects yield for `sqUSD` holders) if NAV increased
- Burns `qUSD` from `sqUSD` balance (which reflects losses for `sqUSD` holders) if NAV decreased
- Transfer assets to `LiquidityNode` if `assetsDelta` positive
- Transfer assets from `LiquidityNode` if `assetsDelta` negative
- Stores new NAV
