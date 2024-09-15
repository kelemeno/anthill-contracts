// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {Anthill2 as Anthill, DagVote} from "../src/Anthill2.sol";

contract CalculateRep is Script {
    address oldAddress = 0x052B66427EE6560e2dF0b5d7463FAdAd6b8206E9;
    Anthill public anthillOld = Anthill(oldAddress);

    function run() public {
        uint256 privateKey = 0x01;

        vm.startBroadcast(privateKey);

        // uint256 root = anthillOld.calculateReputation(0xE2fC7b6b27800D60b8037C59B8a4c5c034dc5419);

        // solhint-disable-next-line no-console
        // console.log("root rep: ", root);
        // calculateRepRec(root, anthillOld);
        // TODO: add a second method to anthill dag which calculates rep for a single node. Then we can calculate rep for all nodes efficiently, buttom up. This should be in a single tx, to save fees. Finally, we should call that method here.

        vm.stopBroadcast();
    }
}

contract CalculateRepForAll is Script {
    address oldAddress = 0xb2218969ECF92a3085B8345665d65FCdFED9F981;
    Anthill public anthill = Anthill(oldAddress);

    function run() public {
        uint256 privateKey = 0x01;

        vm.startBroadcast(privateKey);

        // anthill.recalculateAllReputation();

        vm.stopBroadcast();
    }
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
                anthill.joinTree(
                    address(uint160(2 * 2 ** i + 2 * j + 1)),
                    string("Name"),
                    address(uint160(2 ** i + j))
                );
            }
        }

        // adding dag votes
        for (uint256 i = 3; i < 8; i++) {
            for (uint256 j = 0; j < 2 ** (i - 1); j++) {
                // e.g. 2*2**i+2*j = 2*2**3+2*0 = 2*8+0 = 16, this has relRoot 2. We give dag votes to 4, 5, 8, 9 10 11
                (address voter, ) = anthill.findRelRoot(address(uint160(2 * 2 ** i + 2 * j)));
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 2 * uint160(voter)), 1);

                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(3 + 4 * uint160(voter)), 1);

                // // in this case we add dag votes to depth one above us
                // if (i>=4){
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(voter)));
                // }
            }
        }

        vm.stopBroadcast();
    }
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
                (address voter, ) = anthill.findRelRoot(address(uint160(2 * 2 ** i + 2 * j)));
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 2 * uint160(voter)), 1);

                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(1 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(2 + 4 * uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2 * 2 ** i + 2 * j)), address(3 + 4 * uint160(voter)), 1);

                // // in this case we add dag votes to depth one above us
                // if (i>=4){
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(voter)));
                // }
            }
        }

        vm.stopBroadcast();
    }
}
