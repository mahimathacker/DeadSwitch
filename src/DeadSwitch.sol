// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


import { IDeadSwitch} from "./interfaces/IDeadSwitch.sol";
import { IYieldAdapter} from "./interfaces/IYieldAdapter.sol";
import { IWillRegistry } from "./interfaces/IWillRegistry.sol";
import { IStreamEngine} from "./interfaces/IStreamEngine.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/** 
 @title DeadSwitch - On-Chain Crypto Inheritance Vault
 @author DeadSwitch Protocol
 @notice A dead man's switch vault with Aave V3 yield and conditional distribution to beneficiaries
 @dev Uses packed storage (31 bytes in Slot 0) and transient storage reentrancy guard
*/
contract DeadSwitch is  IDeadSwitch, Ownable, ReentrancyGuardTransient  {
   using SafeERC20 for IERC20;

uint256 private constant MAX_BENEFICIARIES = 10;
uint256 private constant MIN_CHECKIN_INTERVAL = 7 days;
uint256 private constant MAX_CHECKIN_INTERVAL = 365 days;
uint256 private constant BASIS_POINTS = 10_000;


// Immutables

address private immutable vault;
IYieldAdapter private immutable i_yieldAdapter;
IWillRegistry private immutable i_willRegistry;
IStreamEngine private immutable i_streamEngine;

// Slot 0: Hot slot - ALL packed into 31 bytes, single SLOAD/SSTORE

VaultState private s_state;
uint48 private s_lastCheckIn;
uint48 private s_stateChangedAt; 
uint48 private s_checkInInterval;
uint48 private s_warningPeriod;
uint48 private s_gracePeriod;

// Slot 1: Dynamic array of supported token addresses
address[] private s_supportedTokens;

// Slot 2: Quick lookup to avoid duplicate token entries
mapping(address => bool) private s_tokenExists;


    modifier  onlyInState(VaultState requiredState) {
        if (s_state != requiredState) {
            revert WrongState(s_state, requiredState);
        }
        _;
    }

    /**
     * @notice Deploys a new DeadSwitch vault with the given owner and timing configuration
     * @dev Sets all immutables and initializes Slot 0 storage with Active state and current timestamp
     * @param owner The wallet address that will own and control this vault
     * @param yieldAdapter The deployed YieldAdapter contract address for Aave V3 integration
     * @param willRegistry The deployed WillRegistry contract address for beneficiary management
     * @param streamEngine The deployed StreamEngine contract address for time-released payments
     * @param checkInInterval How often the owner must check in (seconds, min 7 days, max 365 days)
     * @param warningPeriod How long the warning state lasts after a missed check-in (seconds)
     * @param gracePeriod How long the final grace period lasts before distribution (seconds)
     */

    constructor (
        address owner,
        address yieldAdapter,
        address willRegistry,
        address streamEngine,
        uint48 checkInInterval,
        uint48 warningPeriod,
        uint48 gracePeriod
    ) Ownable(owner) {

        if (owner == address(0)) revert NotOwner();
        if (yieldAdapter == address(0)) revert InvalidConfig();
        if (willRegistry == address(0)) revert InvalidConfig();
        if (streamEngine == address(0)) revert InvalidConfig();
        if (checkInInterval < MIN_CHECKIN_INTERVAL) revert InvalidConfig();
        if (checkInInterval > MAX_CHECKIN_INTERVAL) revert InvalidConfig();
        if (warningPeriod == 0) revert InvalidConfig();
        if (gracePeriod == 0) revert InvalidConfig();
    
        i_yieldAdapter = IYieldAdapter(yieldAdapter);
        i_willRegistry = IWillRegistry(willRegistry);
        i_streamEngine = IStreamEngine(streamEngine);

        s_state = VaultState.Active;
        s_lastCheckIn = uint48(block.timestamp);
        s_stateChangedAt = uint48(block.timestamp);
        s_checkInInterval = checkInInterval;
        s_warningPeriod = warningPeriod;
        s_gracePeriod = gracePeriod;
    }

    receive() external payable {}

function checkIn() external onlyOwner {
    VaultState  currentState = s_state;

    //Wrong state: you're in Distributing, but this function requires Active

     if (currentState == VaultState.Distributing || currentState == VaultState.Completed) {
            revert WrongState(currentState, VaultState.Active);

        // If not already Active, transition back to Active
        if (currentState != VaultState.Active) {
            s_state = VaultState.Active;
            emit StateChanged(currentState, VaultState.Active, block.timestamp);
        }
        }

        s_lastCheckIn = uint48(block.timestamp);
        s_stateChangedAt = uint48(block.timestamp);

        emit CheckedIn(msg.sender, block.timestamp);
} 

 function depositETH() external payable onlyOwner onlyInState(VaultState.Active) nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        // TODO: Wrap ETH to WETH and deposit to Aave via i_yieldAdapter
        // For now, vault just holds ETH

        emit Deposited(address(0), msg.value);
    }


function depositToken(address token, uint256 amount) external onlyOwner onlyInState(VaultState.Active) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert UnsupportedToken();

        // Track token if first time seeing it
        if (!s_tokenExists[token]) {
            s_supportedTokens.push(token);
            s_tokenExists[token] = true;
        }

        // CEI: Pull tokens from owner to vault
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Deposit to Aave for yield
        IERC20(token).safeIncreaseAllowance(address(i_yieldAdapter), amount);
        i_yieldAdapter.depositToAave(token, amount);

        emit Deposited(token, amount);
        emit DepositedToYield(token, amount);
    }

 function withdrawETH(uint256 amount) external onlyOwner onlyInState(VaultState.Active) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();

        // CEI: Effects before interaction
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert ETHTransferFailed();

        emit Withdrawn(address(0), amount);
    }

function withdrawToken(
        address token,
        uint256 amount
    ) external onlyOwner onlyInState(VaultState.Active) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert UnsupportedToken();

        // Withdraw from Aave first
        uint256 withdrawn = i_yieldAdapter.withdrawFromAave(token, amount);

        // Transfer to owner
        IERC20(token).safeTransfer(msg.sender, withdrawn);

        emit Withdrawn(token, withdrawn);
        emit WithdrawnFromYield(token, withdrawn);
    }

function setWill(Beneficiary[] calldata beneficiaries) external onlyOwner onlyInState(VaultState.Active) {
        if (beneficiaries.length == 0) revert NoBeneficiaries();
        if (beneficiaries.length > MAX_BENEFICIARIES) revert InvalidConfig();

        // Validate percentages sum to 100%
        uint256 totalPercentage;
        for (uint256 i; i < beneficiaries.length;) {
            totalPercentage += beneficiaries[i].percentage;
            unchecked { ++i; }
        }
        if (totalPercentage != BASIS_POINTS) revert InvalidPercentages();

        // Forward to WillRegistry (handles timelock internally)
        i_willRegistry.proposeWill(beneficiaries);

        emit WillUpdated(beneficiaries.length, block.timestamp + i_willRegistry.getTimelockDuration());
    }

 function updateConfig(
        uint48 checkInInterval,
        uint48 warningPeriod,
        uint48 gracePeriod
    ) external onlyOwner onlyInState(VaultState.Active) {
        if (checkInInterval < MIN_CHECKIN_INTERVAL) revert InvalidConfig();
        if (checkInInterval > MAX_CHECKIN_INTERVAL) revert InvalidConfig();
        if (warningPeriod == 0) revert InvalidConfig();
        if (gracePeriod == 0) revert InvalidConfig();

        s_checkInInterval = checkInInterval;
        s_warningPeriod = warningPeriod;
        s_gracePeriod = gracePeriod;

        emit ConfigUpdated(checkInInterval, warningPeriod, gracePeriod);
    }

     function cancelDistribution() external onlyOwner onlyInState(VaultState.GracePeriod) {
        s_state = VaultState.Active;
        s_lastCheckIn = uint48(block.timestamp);
        s_stateChangedAt = uint48(block.timestamp);

        emit DistributionCancelled(block.timestamp);
        emit StateChanged(VaultState.GracePeriod, VaultState.Active, block.timestamp);
    }

     function triggerWarning() external onlyInState(VaultState.Active) {
        if (block.timestamp < s_lastCheckIn + s_checkInInterval) {
            revert CheckInNotExpired();
        }

        s_state = VaultState.Warning;
        s_stateChangedAt = uint48(block.timestamp);

        emit StateChanged(VaultState.Active, VaultState.Warning, block.timestamp);
    }
     
    function triggerGracePeriod() external onlyInState(VaultState.Warning) {
        if (block.timestamp < s_stateChangedAt + s_warningPeriod) {
            revert WarningNotExpired();
        }

        s_state = VaultState.GracePeriod;
        s_stateChangedAt = uint48(block.timestamp);

        emit StateChanged(VaultState.Warning, VaultState.GracePeriod, block.timestamp);
    }

    function executeDistribution() external onlyInState(VaultState.GracePeriod) nonReentrant {
        if (block.timestamp < s_stateChangedAt + s_gracePeriod) {
            revert GracePeriodNotExpired();
        }

        // --- Effects: Update state BEFORE any external calls (CEI) ---
        s_state = VaultState.Distributing;
        s_stateChangedAt = uint48(block.timestamp);
        emit StateChanged(VaultState.GracePeriod, VaultState.Distributing, block.timestamp);

        // --- Interactions: Withdraw all from Aave ---
        uint256 tokenCount = s_supportedTokens.length;
        for (uint256 i; i < tokenCount;) {
            address token = s_supportedTokens[i];
            i_yieldAdapter.withdrawAll(token);
            unchecked { ++i; }
        }

        // --- Interactions: Distribute per will ---
        Beneficiary[] memory will = i_willRegistry.getActiveWill();
        if (will.length == 0) revert NoBeneficiaries();

        for (uint256 t; t < tokenCount;) {
            address token = s_supportedTokens[t];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));

            if (tokenBalance > 0) {
                for (uint256 b; b < will.length;) {
                    uint256 share = (tokenBalance * will[b].percentage) / BASIS_POINTS;

                    if (share > 0) {
                        if (will[b].distributionType == DistributionType.Instant) {
                            // Instant: send directly to beneficiary
                            IERC20(token).safeTransfer(will[b].beneficiary, share);
                            emit Distributed(will[b].beneficiary, token, share, DistributionType.Instant);
                        } else {
                            // Streamed: send to StreamEngine and create stream
                            IERC20(token).safeTransfer(address(i_streamEngine), share);
                            i_streamEngine.createStream(
                                will[b].beneficiary,
                                token,
                                share,
                                will[b].streamDuration
                            );
                            emit Distributed(will[b].beneficiary, token, share, DistributionType.Streamed);
                        }
                    }

                    unchecked { ++b; }
                }
            }

            unchecked { ++t; }
        }

        // --- Distribute ETH if any ---
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            for (uint256 b; b < will.length;) {
                uint256 share = (ethBalance * will[b].percentage) / BASIS_POINTS;

                if (share > 0) {
                    if (will[b].distributionType == DistributionType.Instant) {
                        (bool success,) = will[b].beneficiary.call{value: share}("");
                        if (!success) revert ETHTransferFailed();
                        emit Distributed(will[b].beneficiary, address(0), share, DistributionType.Instant);
                    }
                    // NOTE: ETH streaming requires wrapping to WETH — handled in v2
                }

                unchecked { ++b; }
            }
        }

        // --- Final state ---
        s_state = VaultState.Completed;
        s_stateChangedAt = uint48(block.timestamp);
        emit StateChanged(VaultState.Distributing, VaultState.Completed, block.timestamp);
    }
     function checkUpkeep(
        bytes calldata
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        VaultState currentState = s_state;

        if (currentState == VaultState.Active) {
            if (block.timestamp >= s_lastCheckIn + s_checkInInterval) {
                return (true, abi.encode(uint8(0))); // 0 = triggerWarning
            }
        } else if (currentState == VaultState.Warning) {
            if (block.timestamp >= s_stateChangedAt + s_warningPeriod) {
                return (true, abi.encode(uint8(1))); // 1 = triggerGracePeriod
            }
        } else if (currentState == VaultState.GracePeriod) {
            if (block.timestamp >= s_stateChangedAt + s_gracePeriod) {
                return (true, abi.encode(uint8(2))); // 2 = executeDistribution
            }
        }

        return (false, "");
    }

 function performUpkeep(bytes calldata performData) external {
        uint8 action = abi.decode(performData, (uint8));

        if (action == 0) {
            triggerWarning();
        } else if (action == 1) {
            triggerGracePeriod();
        } else if (action == 2) {
            executeDistribution();
        }
    }
function claimStream(address token) external {
        uint256[] memory streamIds = i_streamEngine.getStreamsByRecipient(msg.sender);

        bool claimed;
        for (uint256 i; i < streamIds.length;) {
            IStreamEngine.Stream memory stream = i_streamEngine.getStream(streamIds[i]);
            if (stream.token == token && stream.active) {
                i_streamEngine.claim(streamIds[i]);
                claimed = true;
            }
            unchecked { ++i; }
        }

        if (!claimed) revert NotBeneficiary();
    }


    /*///////////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////////*/

    function getState() external view returns (VaultState) {
        return s_state;
    }

     function getOwner() external view returns (address) {
        return msg.sender;
    }

    function getConfig() external view returns (VaultConfig memory) {
        return VaultConfig({
            checkInInterval: s_checkInInterval,
            warningPeriod: s_warningPeriod,
            gracePeriod: s_gracePeriod
        });
    }

     function getLastCheckIn() external view returns (uint256) {
        return s_lastCheckIn;
    }

     function getTimeUntilExpiry() external view returns (uint256) {
        uint256 deadline = uint256(s_lastCheckIn) + uint256(s_checkInInterval);
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    function getBalance(address token) external view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        // Idle balance in vault + balance earning yield in Aave
        uint256 idle = IERC20(token).balanceOf(address(this));
        uint256 inAave = i_yieldAdapter.getAaveBalance(token);
        return idle + inAave;
    }

     function getWill() external view returns (Beneficiary[] memory) {
        return i_willRegistry.getActiveWill();
    }

    function getClaimable(address beneficiary, address token) external view returns (uint256) {
        uint256[] memory streamIds = i_streamEngine.getStreamsByRecipient(beneficiary);

        uint256 total;
        for (uint256 i; i < streamIds.length;) {
            IStreamEngine.Stream memory stream = i_streamEngine.getStream(streamIds[i]);
            if (stream.token == token && stream.active) {
                total += i_streamEngine.getClaimable(streamIds[i]);
            }
            unchecked { ++i; }
        }

        return total;
    }

}


