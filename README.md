# Upgradeable Oracle
**DISCLAIMER: Project Beta. Test thouroughly before any Mainnet launch.**
[![built-with openzeppelin](https://img.shields.io/badge/built%20with-OpenZeppelin-3677FF)](https://docs.openzeppelin.com/)

## Description
This small project introduces a version of Chainlink's `Oracle.sol` contract that conforms to OpenZeppelin's Proxy Pattern. For this to be possible, the contract may not have a constructor and must use an initializer. Read more about this on OpenZeppelin's website here (https://docs.openzeppelin.com/upgrades/2.6/proxies#the-constructor-caveat)

## Motivations
Problem: Once deployed a Chainlink node can be modified in many ways to improve performance and add new jobs. However, the Oracle contract address remains static and is highly coupled with other services. A node can respond to requests from various oracles but consumers are often reliant on a static address. Most notably, Oracles are listed by online registries such as [market.link](market.link) and used by DApps or other high-level contracts (eg. [Aggregator](https://eth-usd-aggregator.chain.link/)).

Solution: Use the OpenZeppelin Proxy architecture to have an *upgradeable* Oracle that conserves the same interface and that can have incrementally added additional features.

## OracleUpgradeable.sol
Upgradeable Oracle contract compatible with Chainlink nodes and LINK token interface. This requires a port to Solidity ^0.5.0. Contract can manage standard Chainlink requests and emit event logs. Read more about the architecture here https://docs.openzeppelin.com/upgrades/2.6/

## OraclePriced.sol
Example incremental feature for Oracle contract that adds job-level minimum pricing requirements. With this feature, the Oracle enforces a minimum LINK payment for each job and rejects any request that does not meet the threshold for the job (default is 0, so will **not** be rejected). In addition, pricing is public so users and contracts can know the price of each job in advance. This is different from setting the `MINIMUM_CONTRACT_PAYMENT` environment variable as it is enforced on-chain and can be customized for each job.

Not only is this a useful feature, but the upgradeable architecture means this can be implemented *after* having deployed the upgradeable oracle. See example below.

## Example
### On-chain example
The `UpgradeableContract.sol` conforms to the interface and will respond to jobs from consumers correctly. It is compatible with the other Chainlink contracts (even though some are compiled with older compilers).

Deployed Version:
https://ropsten.etherscan.io/address/0xb4d58a6071564b456e37fedc5bd48f73ffee0cfc#readProxyContract

### Create Upgradeable Contract
This creates the proxy contract architecture and deploys the first logic contract.
After compiling the contracts with `truffle compile`:
```
oz create
? Pick a network ropsten
? Pick a contract to instantiate MyOracle
? Select which function * initialize(_link: address) 
? _link (address): 0x20fe562d797a42dcb3399062ae9546cd06f63280 //Ropsten
Creating instance ...
```

### Upgrading
Upgrading refers to changing the logic contract. Note that storage slots cannot be removed and can only be added. Learn more here https://docs.openzeppelin.com/

Change the implementation in `MyOracle.sol`
```
//contract MyOracle is OracleUpgradeable {}
contract MyOracle is OraclePriced {};
```

Compile and upgrade contract.
```
oz upgrade
...
New variable 'mapping(key => uint256) _jobPricing' was added in contract OraclePriced in contracts/OraclePriced.sol:1 at the end of the contract.
? Which instances would you like to upgrade? Choose by address
? Pick an instance to upgrade MyOracle at 0xdbB6fa03a9e7B7b67146a86a55008Ef47Bc126AC
? Call a function on the instance after upgrading it? n
Contract MyOracle at 0xdbB6fa03a9e7B7b67146a86a55008Ef47Bc126AC is up to date.
```

#### Logic Contract & Storage slots
Upgrades update the proxy contract to point to a new logic contract to which the delegatecalls will be forwarded to. You must be careful to conserve storage slots in the same order and avoid deleting them. For derived contracts such as `OraclePriced.sol`, we preemptivaley reserve 50 storage slots for the parent contract `OracleUpgradeable.sol`.
```
uint256[50] private ______gap;
```
This does not incur additional gas cost but merely "shifts" the positioning of the variables of the child contract. This enables the possibility of adding storage slots to the parent contract so long as the '______gap' is reduced equally. Adding 1 variable to `OracleUpgradeable.sol` and reducing the gap by 1 therefore would conserve storage alignment in all child contracts.  Not that `constant` variables take up no storage space as they are replaced by their computed values at compile time.


### Cost
Looking at before after examples. The proxy contract architecture comes at very little cost compared to the benefits it offers. Most of the cost of Oracle Requests comes from the data payload. From my tests the increase was 2k for a tx that cost 200k, which comes out at about +1% gas cost.

## Low-level OracleRequest() event log
Due to how Solidity ^0.5.0 encodes the event with padding. Chainlink nodes have compatibility issues with the `emit Event()` form of event logs. We therefore resort to using inline assembly with a lowlevel `log2()` call to emit the equivalent event that can be correctly parsed by all Chainlink nodes. In the future, it would be beneficial for nodes to consider the data length field when parsing events, instead of assuming all bytes are part of the data. Low-level event logs provide backwards compatibility with the current nodes and are therefore the most practical solution as of now.

## Security
The project aims to change as little code as possible from the original implementation (see https://github.com/smartcontractkit/chainlink). In addition to replacing the constructor, the original interfaces and `Oracle.sol` code had to be ported to be compatible with Solidity ^0.5.0. This entails some minor syntactic changes but no substantial difference with the original implementation. 

## Review Needed
This updated version of the `Oracle.sol` contract has minimal changes, but I cannot guarantee as of now that it 100% identical to the old one in behaviour. The port from Solidity 0.4 to 0.5 entails some minor changes that can have some subtle but noticeable effects (eg. the behaviours encode() vs encodePacked() vs encodeWithSignature()). My on-chain test currently seemed to indicate that the Oracle behaves as the old contract so I doubt there are any critical bugs introduced by the minor version upgrade changes.

I would like to have a couple extra pairs of eyes review the contract before feeling comfortable with recommending this in production. One advantage of the proxy architecture is if there are minor bugs, patching them is as trivial as updating the logic contract with `oz upgrade`.