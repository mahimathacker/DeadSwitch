# DeadSwitch

**On-Chain Crypto Inheritance Protocol**

Your crypto earns yield while you're alive. It goes to your family when you're gone.

> $600B+ in crypto is projected to become permanently inaccessible by 2026. 3.7M Bitcoin (20% of total supply) is already lost forever. 90% of holders worry about inheritance, but only 15% have a plan. DeadSwitch fixes this.

---

## How It Works

1. **Create a Vault** - Deposit ETH or ERC-20 tokens into your personal DeadSwitch vault
2. **Earn Yield** - Your assets are deposited into Aave V3 and earn interest automatically
3. **Set Your Will** - Choose who gets what: percentages, instant vs streamed over time
4. **Check In** - Prove you're alive periodically (every 30, 60, 90 days, you choose)
5. **If You Stop** - Warning > Grace Period > Automatic distribution to your beneficiaries

```
Owner checks in every 30 days
         |
         |  Check-in received
         v
    +---------+
    |  ACTIVE  |<------ checkIn() resets timer
    +----+----+
         |  Missed check-in
         v
    +---------+
    | WARNING |  7 days for owner to respond
    +----+----+
         |  Still no response
         v
    +--------------+
    | GRACE PERIOD |  72 hours, last chance
    +------+-------+
           |  No response
           v
    +--------------+
    | DISTRIBUTING |  Pulls from Aave, sends to heirs
    +------+-------+
           |
           v
    +--------------+
    |  COMPLETED   |  Vault empty, all funds distributed
    +--------------+
```

---

## The Problem

| Stat | Source |
|------|--------|
| 3.7M Bitcoin (20% of supply) permanently lost | Chainalysis 2024 |
| $600B+ in crypto at risk of becoming inaccessible by 2026 | Industry estimates |
| 90% of crypto holders worry about inheritance | Fidelity Digital Assets 2024 |
| Only 15% have any estate plan for crypto | Fidelity Digital Assets 2024 |
| QuadrigaCX CEO death locked $240M in customer funds | Real incident, 2019 |
| Stefan Thomas forgot password to $200M+ in Bitcoin | Real incident, ongoing |

Existing solutions like Sarcophagus and Safe Haven pass encrypted keys to heirs, not actual assets. They're treasure maps, not treasure. If the heir doesn't know how to use a seed phrase, the crypto is still lost.

---

## What Makes DeadSwitch Different

| Feature | Sarcophagus | Safe Haven | DeadSwitch |
|---------|-------------|------------|------------|
| Holds actual assets | No | No | Yes |
| Earns yield while alive | No | No | Yes (Aave V3) |
| Automated distribution | No | No | Yes (Chainlink) |
| Streamed inheritance | No | No | Yes |
| Grace period safeguard | No | No | Yes |
| No seed phrase sharing | No | No | Yes |
| Multi-asset support | No | No | Yes |

---

## Architecture

```
DeadSwitch.sol (Main Vault)
    |
    |-- YieldAdapter.sol ---- Aave V3 Pool (supply/withdraw)
    |
    |-- WillRegistry.sol ---- Beneficiary storage + 48hr timelock
    |
    |-- StreamEngine.sol ---- Time-released payments to heirs
    |
    +-- Chainlink Automation -- Monitors check-ins, triggers state changes

DeadSwitchFactory.sol ---- Deploys individual vaults per user
```

| Contract | Purpose |
|----------|---------|
| `DeadSwitch.sol` | Core vault - state machine, deposits, withdrawals, check-ins, distribution |
| `YieldAdapter.sol` | Wraps Aave V3 `supply()` / `withdraw()` - isolates yield logic |
| `WillRegistry.sol` | Stores beneficiaries with 48-hour timelock on changes |
| `StreamEngine.sol` | Linear payment streams for gradual inheritance distribution |
| `DeadSwitchFactory.sol` | Factory pattern - deploys vaults for users in one transaction |

---

## Gas Optimization

| Optimization | Technique | Savings |
|-------------|-----------|---------|
| Storage packing | 31 bytes packed into single Slot 0 | 1 SLOAD instead of 6 |
| Immutables | Contract references in bytecode | 0 gas vs 2,100 gas per read |
| Transient reentrancy | `ReentrancyGuardTransient` (EIP-1153) | 200 gas vs 7,100 gas |
| Custom errors | `if/revert` pattern | Cheaper than `require` strings |
| Unchecked increments | `unchecked { ++i; }` in loops | Saves overflow check gas |
| SafeERC20 | Handles non-standard ERC-20 tokens | Prevents silent failures |

**Storage Layout:**

```
IMMUTABLES (zero cost):  i_yieldAdapter, i_willRegistry, i_streamEngine
CONSTANTS (zero cost):   MAX_BENEFICIARIES, MIN/MAX_CHECKIN_INTERVAL, BASIS_POINTS

SLOT 0 (31 bytes):       s_state (1B) + s_lastCheckIn (6B) + s_stateChangedAt (6B)
                         + s_checkInInterval (6B) + s_warningPeriod (6B) + s_gracePeriod (6B)

SLOT 1:                  s_supportedTokens[]
SLOT 2:                  s_tokenExists mapping

TRANSIENT:               Reentrancy lock (100 gas read + 100 gas write)
```

---

## Security

- **CEI Pattern** - Checks-Effects-Interactions on every external function
- **Transient Reentrancy Guard** - OpenZeppelin's `ReentrancyGuardTransient`
- **SafeERC20** - Handles fee-on-transfer and non-standard return tokens
- **48-Hour Timelock** - Will changes require 48-hour waiting period
- **Ownable with Disabled Transfer** - `transferOwnership` and `renounceOwnership` are overridden to revert
- **Custom Errors** - Gas-efficient error handling with descriptive revert reasons
- **State Machine Enforcement** - Every function validates current state before execution
- **Slither Analysis** - Static analysis on all contracts
- **Fuzz Testing** - Foundry fuzz + invariant tests

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Smart Contracts | Solidity 0.8.28 |
| Framework | Foundry (forge, cast, anvil) |
| Yield | Aave V3 on Arbitrum |
| Automation | Chainlink Automation (Keepers) |
| Chain | Arbitrum One |
| Testing | Foundry (unit, fuzz, invariant, fork tests) |
| Security | Slither, Aderyn |
| Token Standard | ERC-20 (SafeERC20), ETH |
| Libraries | OpenZeppelin Contracts (Ownable, ReentrancyGuardTransient, SafeERC20) |

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Installation

```bash
git clone https://github.com/YOUR_USERNAME/deadswitch.git
cd deadswitch
forge install
forge build
```

### Run Tests

```bash
# Unit tests
forge test

# Fork tests against live Arbitrum Aave
forge test --fork-url $ARBITRUM_RPC -vvv

# Fuzz tests
forge test --match-test testFuzz

# Coverage
forge coverage
```

### Deploy

```bash
# Arbitrum Sepolia (testnet)
forge script script/DeployDeadSwitch.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast --verify

# Arbitrum One (mainnet)
forge script script/DeployDeadSwitch.s.sol --rpc-url $ARBITRUM_RPC --broadcast --verify
```

---

## Project Structure

```
deadswitch/
├── src/
│   ├── interfaces/
│   │   ├── IDeadSwitch.sol
│   │   ├── IYieldAdapter.sol
│   │   ├── IWillRegistry.sol
│   │   ├── IStreamEngine.sol
│   │   └── IDeadSwitchFactory.sol
│   ├── DeadSwitch.sol
│   ├── YieldAdapter.sol
│   ├── WillRegistry.sol
│   ├── StreamEngine.sol
│   └── DeadSwitchFactory.sol
├── test/
│   ├── unit/
│   │   ├── DeadSwitchTest.t.sol
│   │   ├── YieldAdapterTest.t.sol
│   │   ├── WillRegistryTest.t.sol
│   │   └── StreamEngineTest.t.sol
│   ├── fuzz/
│   │   └── DeadSwitchFuzz.t.sol
│   ├── invariant/
│   │   └── DeadSwitchInvariant.t.sol
│   └── fork/
│       └── AaveForkTest.t.sol
├── script/
│   └── DeployDeadSwitch.s.sol
├── foundry.toml
├── SECURITY.md
└── README.md
```

---

## Deployments

| Network | Contract | Address |
|---------|----------|---------|
| Arbitrum Sepolia | DeadSwitchFactory | `TBD` |
| Arbitrum Sepolia | DeadSwitch (impl) | `TBD` |
| Arbitrum One | DeadSwitchFactory | `TBD` |
| Arbitrum One | DeadSwitch (impl) | `TBD` |

---

## Roadmap

- [x] Interface design and architecture
- [x] Storage layout optimization
- [ ] Core vault implementation (DeadSwitch.sol)
- [ ] Aave V3 integration (YieldAdapter.sol)
- [ ] Beneficiary management (WillRegistry.sol)
- [ ] Payment streaming (StreamEngine.sol)
- [ ] Factory deployment (DeadSwitchFactory.sol)
- [ ] Unit + fuzz + invariant tests
- [ ] Fork tests against live Arbitrum Aave
- [ ] Slither + Aderyn security analysis
- [ ] Testnet deployment (Arbitrum Sepolia)
- [ ] Mainnet deployment (Arbitrum One)
- [ ] Frontend (Next.js + wagmi + viem)
- [ ] Notification layer (email, push, Telegram)

---

## Contributing

This is a personal project but PRs are welcome. If you find a bug or have an optimization suggestion, open an issue.

---

## License

MIT

---

## Acknowledgments

- [Aave V3](https://aave.com) - Yield generation
- [Chainlink](https://chain.link) - Automation
- [OpenZeppelin](https://openzeppelin.com) - Contract standards
- [Cyfrin Updraft](https://updraft.cyfrin.io) - Solidity best practices
- [Foundry](https://book.getfoundry.sh) - Development framework

---

*Built by Mahima Thacker, because your crypto shouldn't die with you.*
