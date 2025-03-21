// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {console} from "forge-std/console.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

import {EvenBlockFee} from "hooks/EvenBlockFee.sol";

contract EvenBlockFeeTest is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    EvenBlockFee public hook;

    PoolSwapTest.TestSettings public testSettings;
    IPoolManager.SwapParams public swapParams;

    function setUp() public {
        // 1. Deploy v4 core and periphery
        deployFreshManagerAndRouters();

        // 2. Deploy currencies (ERC20s)
        deployMintAndApprove2Currencies();

        // 3. Get address of the hook
        address hookAddress = address(uint160(Hooks.BEFORE_SWAP_FLAG));

        // 4. Deploy hook code
        deployCodeTo("EvenBlockFee.sol", abi.encode(manager), hookAddress);

        hook = EvenBlockFee(hookAddress);

        // 5. Create pool with hook
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1
        );

        // 6. Add initial liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000000e18,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        // 7. Set swap params
        swapParams = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 1e18,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 100
        });
    }

    function test_balance_changes() public {
        uint256 token1BalanceBefore = currency1.balanceOfSelf();

        swapRouter.swap(key, swapParams, testSettings, ZERO_BYTES);

        uint256 token1BalanceAfter = currency1.balanceOfSelf();

        assertGt(token1BalanceAfter, token1BalanceBefore);
    }

    function test_charges_fee_on_even_blocks() public {
        // Get current block number
        uint256 blockNumber = block.number;

        // If we're on an odd block, roll to the next block to start with an even block
        if (blockNumber % 2 == 1) {
            vm.roll(blockNumber + 1);
        }

        // Test swap on even block (should charge fee = 100)
        vm.expectEmit(true, true, true, true);
        emit EvenBlockFee.SwapFee(100);
        swapRouter.swap(key, swapParams, testSettings, ZERO_BYTES);

        // Roll to odd block
        vm.roll(block.number + 1);

        // Test swap on odd block (should charge fee = 0)
        vm.expectEmit(true, true, true, true);
        emit EvenBlockFee.SwapFee(0);
        swapRouter.swap(key, swapParams, testSettings, ZERO_BYTES);
    }
}
