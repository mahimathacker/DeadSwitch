// SPDK-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDeadSwitch} from "./IDeadSwitch.sol";

/// @title IWillRegistry - Beneficiary & Will Management
/// @notice Stores and manages beneficiary configurations with timelock protection
/// @dev Will changes have a 48-hour timelock to prevent deathbed manipulation

interface IWillRegistry {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyVault();
    error InvalidPercentages();
    error NoBeneficiaries();
    error ZeroBeneficiary();
    error Timelocked(uint256 effectiveAt);
    error NoPendingProposal();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event WillProposed(uint256 beneficiaryCount, uint256 effectiveAt);
    event WillActivated(uint256 beneficiaryCount);
    event WillProposalCancelled();

     /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
      //////////////////////////////////////////////////////////////*/

    /**
     * @notice Proposes a new will configuration, starting a 48-hour timelock before it becomes active
     * @dev Only callable by the vault contract
     *      All beneficiary percentages must sum to exactly 10000 (100%)
     *      Overwrites any existing pending proposal
     * @param beneficiaries The new array of beneficiary configurations
     */

      function proposeWill(IDeadSwitch.Beneficiary[] calldata beneficiaries) external;

     /**
     * @notice Activates a pending will proposal after the 48-hour timelock has passed
     * @dev Anyone can call this once the timelock expires
     *      Replaces the current active will with the proposed one
     */

      function activeWill() external;


    /**
     * @notice Cancels a pending will proposal before it becomes active
     * @dev Only callable by the vault contract (triggered by the owner)
     */

    function cancelProposal() external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    
    /**
     * @notice Returns the current active will with all beneficiary configurations
     * @return The array of active Beneficiary structs
     */

    function getActiveWill() external view returns (IDeadSwitch.Beneficiary[] memory);

    /**
     * @notice Returns the pending proposed will and the timestamp when it becomes activatable
     * @return beneficiaries The proposed beneficiary configurations
     * @return effectiveAt The Unix timestamp when the proposal can be activated
     */

    function getPendingWill() external view returns (IDeadSwitch.Beneficiary[] memory beneficiaries, uint256 effectiveAt);


    /**
     * @notice Checks whether there is a pending will proposal waiting for its timelock to expire
     * @return True if a proposal exists and is waiting for activation
     */

    function hasPendingProposal() external view returns (bool);

    /**
     * @notice Returns the timelock duration that all will changes must wait before activation
     * @return The timelock period in seconds (default 48 hours = 172800 seconds)
     */

    function getTimelockDuration() external pure returns (uint256);

}
