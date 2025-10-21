# Quiet Finance Protocol Contracts

## Tokens
|Token|Price|Type|
|-|-|-|
|qUSD|1 USDC|erc20 stablecoin|
|sqUSD|constantly goes up, reflects yield|erc4626 vault|

## Contracts
- `Strategy` - Contract, which represents one atomic yield source (example: we deposit USDC to Aave Ethereum and get lending yield - it's strategy, USDT Ethereum deposit or USDC Base deposit it's another strategies).
- `LiquidityNode` - Do only one thing: liquidity management. In Quiet Finance ther are multiple instances of this contract will be deployed - for another chains or another liquidity assets (example: contract for USDT on ethereum, contract for USDC on Base).
- `LiquidityEdge` - Contract, which connects two `LiquidityNode` contracts (example: contract for USDC on Ethereum <> USDC on Base via CCTP, contract for USDC on Ethereum <> USDT on Ethereum). `LiquidityEdge` doesn't holds any liquidity, its just moved it from one edge to another.
- `Core` - main contract for all user-ended scenarios. Containts logic for minting qUSD, instant qUSD redeem and normal qUSD redeem (via queue). `Core` contract is `LiquidityNode` (it's also manage liquidity).

### Deposit scenario
   - User calls `Core.issue` to transfer USDC in and mint an equal amount of qUSD to `to`.
   - *Optionally*: User calls `sqUSD.deposit` / `sqUSD.mint` and gets erc4626 sqUSD vault.
   - __NB:__ Funds are sit at `Core` contract and waits for next rebalance.

### Instant redeem scenario
- *If user have sqUSD* User calls `sqUSD.withraw` / `sqUSD.burn` and gets erc20 qUSD token.
- User calls `Core.redeemInstant` to burn qUSD and get USDC.
- __NB:__ Instant redeem can be done only if `Hub` have enough USDC on his balance 
- __NB 2:__ `Hub` takes fee for instant redeem and sends it to Quiet Finance treasury

### Redeem scenario (via queue)
- *If user have sqUSD* User calls `sqUSD.withraw` / `sqUSD.burn` and gets erc20 qUSD token.
- User calls `Core.requestRedeem` to burn qUSD and join the withdrawal queue. `Core` creates redeem request for user and put it into FIFO queue.
- When USDC is prepared, __rebalancer__ calls `setMaxRedeemableId` to allow users reedem his funds.
- When user redeem request processed (eg `redeemRequest.id < maxRedeemableId`), user calls `Core.finishRedeem` and contracts sends him USDC.

### Rebalance scenario
- When __rebalancer__ want to add funds to strategy, it calls `LiquidityNode.enter`
- When __rebalancer__ want to remove funds from strategy, it calls `LiquidityNode.exit`
- When __rebalancer__ want to move funds to another `LiquidityNode`, it calls `LiquidityNode.transferLiquidity`
