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
contract DeadSwitch is IDeadSwitch, ReentrancyGuardTransient  {
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
    }
    
    

}
