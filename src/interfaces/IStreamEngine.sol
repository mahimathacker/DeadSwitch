// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IStreamEngine - Time-Released Payment Streams
/// @notice Handles linear streaming of funds to beneficiaries over configurable durations
/// @dev Similar to Sablier but purpose-built for inheritance distribution


interface IStreamEngine {

     /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyVault();
    error StreamNotFound();
    error NothingToClaim();
    error StreamAlreadyCompleted();
    error NotRecipient();



    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/


    struct Stream {
        address recipient;
        address token;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }


    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event StreamCreated(uint256 indexed streamId, address indexed recipient, address indexed token, uint256 totalAmount, uint256 duration);
    event StreamClaimed(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event StreamCompleted(uint256 indexed streamId);

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new linear payment stream that releases funds to a beneficiary over time
     * @dev Only callable by the vault contract during the distribution phase
     *      Tokens must be transferred to the StreamEngine contract before calling this function
     * @param recipient The beneficiary's wallet address who will receive the streamed funds
     * @param token The ERC-20 token address to stream (address(0) for ETH)
     * @param totalAmount The total amount of tokens to be streamed over the full duration
     * @param duration How long the stream lasts in seconds (e.g., 31536000 for 1 year)
     * @return streamId The unique identifier for the newly created stream
     */

    function createStream(
        address recipient,
        address token,
        uint256 totalAmount,
        uint256 duration
    ) external returns (uint256 streamId);

    /**
     * @notice Allows a beneficiary to claim their vested tokens from an active stream
     * @dev Calculates the vested amount based on linear vesting and transfers unclaimed tokens
     *      Marks the stream as completed if the full amount has been claimed
     * @param streamId The unique identifier of the stream to claim from
     * @return amount The amount of tokens successfully claimed in this transaction
     */

    function claim(uint256 streamId) external returns (uint256 amount);



    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

     /**
     * @notice Returns the full details of a specific payment stream
     * @param streamId The unique identifier of the stream
     * @return The Stream struct containing all stream details
     */

    function getStream(uint256 streamId) external view returns (Stream memory);



     /**
     * @notice Returns the amount of tokens currently available for a beneficiary to claim from a stream
     * @dev Calculates linear vesting: (elapsed / duration) * totalAmount - claimedAmount
     * @param streamId The unique identifier of the stream
     * @return The amount of tokens available to claim right now
     */
    function getClaimable(uint256 streamId) external view returns (uint256);

    /**
     * @notice Returns all stream IDs associated with a specific beneficiary
     * @param recipient The beneficiary's wallet address
     * @return Array of stream IDs belonging to this recipient
     */

    function getStreamsByRecipient(address recipient) external view returns (uint256[] memory);


    /**
     * @notice Returns the total number of streams that have been created across all beneficiaries
     * @return The total stream count
     */

    function getStreamCount() external view returns (uint256);
}