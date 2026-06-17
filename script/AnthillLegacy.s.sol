// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {Anthill, DagVote} from "../src/Anthill.sol";

contract CalculateRep is Script {
    address oldAddress = 0x052B66427EE6560e2dF0b5d7463FAdAd6b8206E9;
    Anthill public anthillOld = Anthill(oldAddress);

    function run() public {
        uint256 privateKey = 0x01;

        vm.startBroadcast(privateKey);

        // TODO: add a method to AnthillDag that calculates reputation for a single node, so reputation
        // for all nodes can be computed efficiently bottom-up in a single tx, then call it here.

        vm.stopBroadcast();
    }

    function test() public {}
}

contract CalculateRepForAll is Script {
    address oldAddress = 0xb2218969ECF92a3085B8345665d65FCdFED9F981;
    Anthill public anthill = Anthill(oldAddress);

    function run() public {
        uint256 privateKey = 0x01;

        vm.startBroadcast(privateKey);

        // TODO: invoke reputation recalculation for all nodes once available on Anthill.

        vm.stopBroadcast();
    }

    function test() public {}
}

contract AnthillScript1 is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0x01;
        vm.startBroadcast(privateKey);

        anthill = new Anthill();

        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));

        // adding tree votes
        for (uint256 i = 1; i < 8; i++) {
            for (uint256 j = 0; j < 2 ** (i - 1); j++) {
                anthill.joinTree(address(uint160(2 * 2 ** i + 2 * j)), string("Name"), address(uint160(2 ** i + j)));
                anthill.joinTree(address(uint160(2 * 2 ** i + 2 * j + 1)), string("Name"), address(uint160(2 ** i + j)));
            }
        }

        // adding dag votes
        for (uint256 i = 3; i < 8; i++) {
            for (uint256 j = 0; j < 2 ** (i - 1); j++) {
                // e.g. 2*2**i+2*j = 2*2**3+2*0 = 2*8+0 = 16, this has relRoot 2. We give dag votes to 4, 5, 8, 9 10 11
                (address voter,) = anthill.findRelRoot(address(uint160(2 * 2 ** i + 2 * j)));
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 2 * uint160(voter)), 1);

                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(3 + 4 * uint160(voter)), 1);
            }
        }

        vm.stopBroadcast();
    }

    function test() public {}
}

contract AnthillScript2 is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);

        anthill = new Anthill();

        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        // anthill.joinTreeAsRoot(address(3), string("root 3, we will want to remove second roots "));

        // adding tree votes
        for (uint256 i = 1; i < 5; i++) {
            for (uint256 j = 0; j < 2 ** (i - 1); j++) {
                anthill.joinTree(address(uint160(2 * (2 ** i + j))), string("Name"), address(uint160(2 ** i + j)));
                anthill.joinTree(address(uint160(2 * (2 ** i + j) + 1)), string("Name"), address(uint160(2 ** i + j)));
            }
        }

        // adding dag votes
        // we add layers 3, 4
        // then we add
        for (uint256 i = 3; i < 5; i++) {
            for (uint256 j = 0; j < 2 ** (i - 1); j++) {
                // e.g. 2*2**i+2*j = 2*2**3+2*0 = 2*8+0 = 16, this has relRoot 2. We give dag votes to 4, 5, 8, 9 10 11
                (address voter,) = anthill.findRelRoot(address(uint160(2 * 2 ** i + 2 * j)));
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 2 * uint160(voter)), 1);

                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(3 + 4 * uint160(voter)), 1);
            }
        }

        vm.stopBroadcast();
    }

    function test() public {}
}
