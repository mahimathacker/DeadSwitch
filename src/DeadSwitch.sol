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

        emit CheckedIn(i_owner, block.timestamp);
} 

 function depositETH() external payable onlyOwner onlyInState(VaultState.Active) nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        // TODO: Wrap ETH to WETH and deposit to Aave via i_yieldAdapter
        // For now, vault just holds ETH

        emit Deposited(address(0), msg.value);
    }


}


