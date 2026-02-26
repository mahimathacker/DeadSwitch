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

/*
* @title IdealSwitch On-Chain Crypto Inheritance Protocol
* @author mahimathacker
* @notice Interface for the Dead man's switch vault with yield generation and conditional inheritance distribution
* @Dev Core vault contract that integrates with YieldAdapter, WillRegistry, StreamEngine, and EmergencyModule
*/

interface IDeadSwitch {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error NotBeneficiary();
    error ZeroAmount();
    error InsufficientBalance();
    error InvalidPercentages();
    error NoBeneficiaries();
    error WillTimelocked(uint256 effectiveAt);
    error CheckInNotExpired();
    error WarningNotExpired();
    error GracePeriodNotExpired();
    error UnsupportedToken();
    error ETHTransferFailed();
    error InvalidConfig();
    error WrongState(VaultState current, VaultState required);

    /*//////////////////////////////////////////////////////////////
                                   ENUMS
      //////////////////////////////////////////////////////////////*/

    /**
     *  @notice The five possible states of a DeadSwitch vault
     *  @dev State transitions: Active → Warning → GracePeriod → Distributing → Completed
     */

    enum VaultState {
        Active,
        Warning,
        GracePeriod,
        Distributing,
        Completed
    }

    /**
     * @notice The two distribution methods for inheritance: Instant lump sum or Streamed over time
     * @param Instant  The entire inheritance is transferred immediately upon distribution
     * @param Streamed  Amount released linearly over a set duration
     */
    enum DistributionType {
        Instant,
        Streamed
    }

    /*//////////////////////////////////////////////////////////////
                            Structs
      //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Struct representing a beneficiary's inheritance details
     *  @param beneficiaryAddress The address of the beneficiary
     *  @param percentage The percentage of the total inheritance allocated to this beneficiary (out of 100)
     *  @param distributionType The method of distribution for this beneficiary (Instant or Streamed)
     *  @param streamDuration If distributionType is Streamed, the duration over which the inheritance will
     */
    struct Beneficiary {
        address beneficiaryAddress;
        uint16 percentage;
        DistributionType distributionType;
        uint256 streamDuration;
    }

    struct VaultConfig {
        uint256 checkInInterval;
        uint256 warningPeriod;
        uint256 gracePeriod;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CheckedIn(address indexed owner, uint256 timestamp);
    event Deposited(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount);
    event StateChanged(VaultState indexed previousState, VaultState indexed newState, uint256 timestamp);
    event WillUpdated(uint256 beneficiaryCount, uint256 effectiveAt);
    event Distributed(
        address indexed beneficiary, address indexed token, uint256 amount, DistributionType distributionType
    );
    event DepositedToYield(address indexed token, uint256 amount);
    event WithdrawnFromYield(address indexed token, uint256 amount);
    event DistributionCancelled(uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the owner to check in and reset the timer, keeping the vault in the Active state
     * @dev Can be called in Active, warning, and GracePeriod states. Resets state back to Active and updates the lastCheckIn timestamp
     */

    function checkIn() external;

    /**
     * @notice Allows the owner to deposit ETH into the vault
     * @dev Only callable by the owner and only in Active state, ETH is forwarded to the Aave via YieldAdapter
     */

    function depositETH() external payable;

    /**
     *  @notice Deposits ERC20 tokens into the vault
     *  @dev Only callable by the owner and only in Active state, tokens are approved and forwarded to the Aave via YieldAdapter
     *  @param token The address of the ERC20 token to be deposited
     *  @param amount The amount of the ERC20 token to be deposited
     */

    function depositToken(address token, uint256 amount) external;

    /**
     *  @notice Allows the owner to withdraw ETH from the vault
     *  @dev Only callable in Active state. Pulls from Aave if needed
     *  @param amount The amount of ETH to be withdrawn
     */

    function withdrawETH(uint256 amount) external;

    /**
     *   @notice Allows the owner to withdraw ERC20 tokens from the vault
     *   @dev Only callable in Active state. Pulls from Aave if needed
     *   @param token The address of the ERC20 token to be withdrawn
     *   @param amount The amount of the ERC20 token to be withdrawn
     */

    function withdrawToken(address token, uint256 amount) external;

    /**
     *  @notice Allows the owner to set or update their will, specifying beneficiaries, their inheritance percentages, and distribution methods
     * @dev Only callable in Active state. Subject to 48-hour timelock All percentages must sum to 10000 (100%)
     * @param beneficiaries Array of beneficiary configurations
     */

    function setWill(Beneficiary[] calldata beneficiaries) external;

    /**
     *  @notice Allows the owner to cancel the inheritance distribution process, resetting the vault back to Active state
     *  @dev Only callable in GracePeriod state by the owner
     */

    function cancelDistribution() external;

    /**
     * @notice Triggers the vault from Active to Warning state when the check-in deadline is missed
     * @dev Called by Chainlink Automation when checkInInterval has passed since lastCheckIn
     *  Anyone can call this, but it will revert if check-in hasn't actually expired
     */

    function triggerWarning() external;

    /**
     * @notice Triggers the vault from Warning to GracePeriod state when the warning period expires
     * @dev Called by Chainlink Automation when warningPeriod has passed since entering Warning
     */

    function triggerGracePeriod() external;

    /**
     * @notice Executes the full distribution of all vault assets to beneficiaries according to the will
     * @dev Called by Chainlink Automation when gracePeriod has passed
     *      Withdraws all assets from Aave, distributes per will configuration
     *      Creates streams via StreamEngine for beneficiaries with Streamed distribution type
     */

    function executeDistribution() external;

    /**
     * @notice Chainlink Automation compatible function that checks whether a state transition is needed
     * @dev Returns true if any state transition timer has expired
     *      Does not modify state, used by Chainlink nodes to determine if performUpkeep should be called
     * @return upkeepNeeded Whether the vault needs a state transition
     * @return performData Encoded data indicating which transition to perform
     */

    function checkUpKeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @notice Chainlink Automation compatible function that performs the actual state transition
     * @dev Decodes performData from checkUpkeep and calls the appropriate trigger function
     * @param performData Encoded data from checkUpkeep indicating which action to execute
     */

    function performUpKeep(bytes calldata performData) external;

    /**
     * @notice Allows a beneficiary to claim their vested funds from an active payment stream
     * @dev Only callable by a registered beneficiary who has an active stream for the given token
     * @param token The token address to claim from the stream
     */

    function chainstreamDistribution(address token) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current state of the vault
     * @return The current VaultState enum value
     */

    function getState() external view returns (VaultState);

    /**
     * @notice Returns the vault owner's wallet address
     * @return The owner address that created this vault
     */

    function getOwner() external view returns (address);

    /**
     * @notice Returns the vault's timing configuration for check-ins, warnings, and grace periods
     * @return The VaultConfig struct containing all interval settings
     */

    function getConfig() external view returns (Beneficiary[] memory);

    /**
     * @notice Returns the timestamp of the owner's most recent check-in
     * @return The Unix timestamp of the last checkIn() call
     */

    function getLastCheckIn() external view returns (uint256);

    /**
     * @notice Returns the number of seconds remaining before the check-in deadline expires
     * @return Seconds remaining until expiry, or 0 if already expired
     */

    function getTimeUntilExpiry() external view returns (uint256);

    /**
     * @notice Returns the total vault balance for a specific token, including yield earned in Aave
     * @dev Combines both idle balance held in the vault and the balance deposited in Aave
     * @param token The token address to check (address(0) for ETH)
     * @return The total balance including accrued yield from Aave
     */

    function getBalance(address token) external view returns (uint256);

    /**
     * @notice Returns the current active will with all beneficiary configurations
     * @return Array of Beneficiary structs representing the current inheritance plan
     */
    function getWill() external view returns (Beneficiary[] memory);

    /**
     * @notice Returns the amount currently available for a beneficiary to claim from their stream
     * @param beneficiary The beneficiary's wallet address
     * @param token The token address to check claimable amount for
     * @return The amount of tokens available to claim right now
     */
    function getClaimable(address beneficiary, address token) external view returns (uint256);
}
