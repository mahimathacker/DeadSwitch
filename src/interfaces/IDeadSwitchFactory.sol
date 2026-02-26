// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IDeadSwitch } from "./IDeadSwitch.sol";

interface IDeadSwitchFactory {


    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error VaultAlreadyExists();
    error IntervalTooShort();
    error IntervalTooLong();


    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultCreated(address indexed owner, address indexed vault, uint256 checkInInterval, uint256 timestamp);


    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new DeadSwitch vault for the caller with custom timing configuration
     * @dev msg.sender becomes the owner of the newly deployed vault
     *      Each address can only create one vault
     * @param checkInInterval How often the owner must check in to prove they are alive (in seconds)
     * @param warningPeriod How long the warning state lasts after a missed check-in (in seconds)
     * @param gracePeriod How long the final grace period lasts before distribution begins (in seconds)
     * @return vault The address of the newly deployed vault contract
     */

     function createVault(
        uint256 checkInInterval,
        uint256 warningPeriod,
        uint256 gracePeriod
    ) external returns (address vault);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/


     /**
     * @notice Returns the vault address associated with a specific owner
     * @param owner The owner's wallet address
     * @return The vault contract address, or address(0) if no vault exists for this owner
     */

    function getVault(address owner) external view returns (address);


    /**
     * @notice Returns all vault addresses that have been deployed through this factory
     * @return Array of all deployed vault contract addresses
     */
    function getAllVaults() external view returns (address[] memory);


    /**
     * @notice Returns the total number of vaults deployed through this factory
     * @return The total vault count
     */

    function getVaultCount() external view returns (uint256);


}