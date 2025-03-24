// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract RaffleScript is Script {
    function run() public {
        vm.startBroadcast();

        // Generate 4 random numbers
        for (uint256 i = 0; i < 4; i++) {
            uint256 rand = randomNumber(1, 9, i);
            console.log("Random number:", rand);
        }
    }

    function randomNumber(
        uint256 min,
        uint256 max,
        uint256 i
    ) internal view returns (uint256) {
        // Using a more secure random number generation approach
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    block.coinbase,
                    block.gaslimit,
                    block.number,
                    msg.sender,
                    2 * i
                )
            )
        );

        // Ensure max is greater than min
        require(max > min, "Max must be greater than min");

        // Calculate the range and add min to get a number in the desired range
        return (seed % (max - min + 1)) + min;
    }
}
