// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Anthill, DagVote} from "../src/Anthill.sol";
import {console} from "forge-std/console.sol";

// for testing uncomment modifiers, and comment msg.sender checks out
// until then test are also commented out.

contract AnthillTestMain is Test {
    Anthill public anthill;

    function setUp() public {
        anthill = new Anthill();
    }

    function test1() public {
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
    }

    function test2() public {
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        anthill.joinTree(address(uint160(4)), string("Name"), address(uint160(2)));
    }

    function test3() public {
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        // anthill.joinTree(address(uint160(4)), string("Name"),address(uint160(2)));

        // adding tree votes. For the numbering we are adding children for i, j voter.
        for (uint256 depth = 1; depth < 5; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum))),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum) + 1)),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
            }
        }
    }

    function test4() public {
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        // anthill.joinTree(address(uint160(4)), string("Name"),address(uint160(2)));

        // adding tree votes. For the numbering we are adding children for i, j voter.
        for (uint256 depth = 1; depth < 5; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum))),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum) + 1)),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
            }
        }

        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));
    }

    function testFull() public {
        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        // anthill.joinTree(address(uint160(4)), string("Name"),address(uint160(2)));

        // adding tree votes. For the numbering we are adding children for i, j voter.
        for (uint256 depth = 1; depth < 5; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum))),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum) + 1)),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
            }
        }

        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));

        for (uint256 depth = 1; depth <= 5; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                for (uint256 recDepth = 1; recDepth < depth; recDepth++) {
                    // we want 2 to receive less, and the second lowest layer to receive more votes.
                    uint256 weight = 1000;
                    if (recDepth == 1) {
                        weight = 1;
                    } else if (recDepth == 4) {
                        weight = 100000;
                    }

                    for (uint256 recVerticalNum = 0; recVerticalNum < 2 ** (recDepth - 1); recVerticalNum++) {
                        // we cannot add votes between parents and children, as we already added those votes in joinTree
                        if (2 ** depth + verticalNum >= 2 * (2 ** recDepth + recVerticalNum)) {
                            if (2 ** depth + verticalNum - 2 * (2 ** recDepth + recVerticalNum) == 0) continue;
                            if (2 ** depth + verticalNum - 2 * (2 ** recDepth + recVerticalNum) == 1) continue;
                        }
                        anthill.addDagVote(
                            address(uint160(2 ** depth + verticalNum)),
                            address(uint160(2 ** recDepth + recVerticalNum)),
                            weight
                        );
                    }
                }
            }
        }
    }
}
