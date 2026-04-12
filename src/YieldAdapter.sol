// SDPX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IYieldAdapter} from "./interfaces/IYieldAdapter.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
/*
@title YieldAdapter - Aave V3 Integration for DeadSwitch
@author Mahima Hacker
@notice Deposits and withdraws vault assets from Aave V3 to earn yield
@dev Zero storage slots — all state is immutable. aTokens are held by this contract
*/

contract YieldAdapter is IYieldAdapter {
    using SafeERC20 for IERC20;

    address private immutable i_vault;
    IPool private immutable i_pool;

mapping(address => address) private s_aTokenCache;

    modifier onlyVault() {
        if (msg.sender != i_vault) revert OnlyVault();
        _;
    }

    /**
     * @notice Deploys the YieldAdapter linked to a specific vault and Aave V3 Pool
     * @param vault The DeadSwitch vault contract address that owns this adapter
     * @param pool The Aave V3 Pool contract address on this chain
     */

    constructor(address vault, address pool) {
        if (vault == address(0)) revert OnlyVault();
        if (pool == address(0)) revert TokenNotSupported();

        i_vault = vault;
        i_pool = IPool(pool);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
      //////////////////////////////////////////////////////////////*/

       function depositToAave(address token, uint256 amount) external onlyVault {
        if (amount == 0) revert ZeroAmount();
        if (!isTokenSupported(token)) revert TokenNotSupported();

        // Transfer tokens from vault to this adapter
        // (vault must have approved this contract before calling)
        IERC20(token).safeTransferFrom(i_vault, address(this), amount);

        // Approve Aave Pool to spend tokens
        IERC20(token).safeIncreaseAllowance(address(i_pool), amount);

        // Supply to Aave — aTokens are minted to this contract (address(this))
        // onBehalfOf = address(this) so this adapter holds the aTokens
        // referralCode = 0 (referral program inactive)
        i_pool.supply(token, amount, address(this), 0);

        emit SuppliedToAave(token, amount);
    }

     function withdrawFromAave(address token, uint256 amount) external onlyVault returns (uint256) {
        if (amount == 0) revert ZeroAmount();

        // Withdraw from Aave — tokens are sent directly to the vault
        // This burns aTokens from this adapter and sends underlying to vault
        uint256 withdrawn = i_pool.withdraw(token, amount, i_vault);

        emit WithdrawnFromAave(token, withdrawn, i_vault);

        return withdrawn;
    }

    function withdrawAll(address token) external onlyVault returns (uint256) {
        // Get current balance (principal + yield)
        uint256 balance = getAaveBalance(token);
        if (balance == 0) return 0;

        // type(uint256).max tells Aave to withdraw everything
        uint256 withdrawn = i_pool.withdraw(token, type(uint256).max, i_vault);

        emit WithdrawnFromAave(token, withdrawn, i_vault);

        return withdrawn;
    }

    

    function getAaveBalance(address token) public view returns (uint256) {
        // Get the aToken address for this asset from Aave
        DataTypes.ReserveData memory reserveData = i_pool.getReserveData(token);
        address aToken = reserveData.aTokenAddress;

        // If token has no reserve in Aave, it's not supported
        if (aToken == address(0)) return 0;

        // aToken.balanceOf() returns principal + accrued yield
        // This is because aTokens use a scaled balance internally
        // that gets multiplied by the liquidity index on every read
        return IERC20(aToken).balanceOf(address(this));
    }

     function isTokenSupported(address token) public view returns (bool) {
        // A token is supported if Aave has a reserve (aToken) for it
        DataTypes.ReserveData memory reserveData = i_pool.getReserveData(token);
        address aToken = reserveData.aTokenAddress;
        return aToken != address(0);
    }
 function getVault() external view returns (address) {
        return i_vault;
    }


    
}
