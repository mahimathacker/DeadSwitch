// SPDK-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IYieldAdapter {
    /*//////////////////////////////////////////////////////////////
                                   ERRORS
      //////////////////////////////////////////////////////////////*/

    error OnlyVault();
    error TokenNotSupported();
    error AaveOperationFailed();

    /*//////////////////////////////////////////////////////////////
                                   EVENTS
       //////////////////////////////////////////////////////////////*/

    event SuppliedToAave(address indexed token, uint256 amount);
    event WithdrawnFromAave(address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL FUNCTIONS
      //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits tokens into Aave V3 lending pool to earn yield on behalf of the vault
     * @dev Calls pool.supply() on Aave V3
     * The vault must have approved this adapter to spend the tokens before calling
     * @param token The ERC-20 token address to supply to Aave
     * @param amount The amount of tokens to supply
     */
    function depositToAave(address token, uint256 amount) external;

    /**
     * @notice Withdraws tokens from Aave V3 lending pool back to the vault, including any accrued yield
     * @dev Calls pool.withdraw() on Aave V3
     *      Pass type(uint256).max as amount to withdraw the entire balance
     * @param token The ERC-20 token address to withdraw from Aave
     * @param amount The amount to withdraw (type(uint256).max for full balance)
     * @return The actual amount withdrawn, which may be higher than deposited due to yield
     */

    function withdrawFromAave(address token, uint256 amount) external returns (uint256);

    /**
     * @notice Withdraws the entire balance of a token from Aave V3 back to the vault
     * @dev Used during the distribution phase to pull all funds out of Aave before sending to beneficiaries
     * @param token The ERC-20 token address to fully withdraw
     * @return The total amount withdrawn including all accrued yield
     */
    function withdrawAll(address token) external returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current balance deposited in Aave for a specific token, including accrued yield
     * @dev Reads the aToken balance which automatically increases over time as yield accrues
     * @param token The underlying ERC-20 token address
     * @return The total balance in Aave including all accrued yield
     */
    function getAaveBalance(address token) external view returns (uint256);

    /**
     * @notice Checks whether a specific token is supported by Aave V3 on the current chain
     * @param token The ERC-20 token address to check
     * @return True if the token can be supplied to Aave, false otherwise
     */

    function isTokenSupported(address token) external view returns (bool);
}
