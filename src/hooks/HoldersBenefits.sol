// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

contract HoldersBenefits is BaseHook {
    IERC721 public immutable nft;

    constructor(IPoolManager _manager, IERC721 _nft) BaseHook(_manager) {
        nft = _nft;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function _beforeSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        uint24 fee = _getFee(sender);

        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            fee
        );
    }

    function _getFee(address _sender) internal view returns (uint24) {
        uint256 balance = _getBalance(_sender);
        if (balance == 0) return 100;
        if (balance > 3) return 0;
        return 50;
    }

    function _afterSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) internal view override returns (bytes4, int128) {
        uint256 balance = _getBalance(sender);

        if (balance > 0) {
            // For NFT holders, give 3% more tokens
            int128 amount0 = delta.amount0();

            // Calculate 3% bonus
            int128 bonus0 = (amount0 * 3) / 100;

            // Return the original delta plus the bonus
            return (this.afterSwap.selector, amount0 + bonus0);
        }

        // For non-holders, return original delta
        return (this.afterSwap.selector, delta.amount0());
    }

    function _getBalance(address _sender) internal view returns (uint256) {
        return nft.balanceOf(_sender);
    }
}
