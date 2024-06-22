// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Anthill2Dev.sol";
import {DagVote} from "../src/Anthill2.sol";
import {console} from "forge-std/console.sol";
import {Utils} from "./Utils.t.sol";

// for testing uncomment modifiers
// until then test are also commented out.

contract Anthill2TestSmall is Test, Utils {
    Anthill2Dev public anthill;

    function setUp() public {
        anthill = new Anthill2Dev();

        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("2"));

        // adding tree votes. For the numbering we are adding children for i, j voter.

        anthill.joinTree(address(4), string("4"), address(2));
        anthill.joinTree(address(5), string("5"), address(2));

        anthill.joinTree(address(8), string("8"), address(4));

        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));
        anthill.addDagVote(address(8), address(5), 1);
    }

    function testSetup() public {}

    function testSwitchPositionWithParent3() public {
        address root = anthill.readRoot();
        assertEq(root, address(2));

        anthill.switchPositionWithParent(address(5));
        root = anthill.readRoot();
        assertEq(root, address(5));

        assert(anthill.readSentTreeVote(address(2)) == address(5));
        assert(anthill.readSentTreeVote(address(4)) == address(5));

        dagConsistencyCheckFrom(anthill, address(5));
        treeConsistencyCheckFrom(address(5));
    }

    function testRootLeave() public {
        address root = anthill.readRoot();
        assertEq(root, address(2));

        address rootV2 = anthill.readRecTreeVote(address(1), 0);
        assertEq(rootV2, address(2));

        anthill.leaveTree(address(2));

        root = anthill.readRoot();
        assertEq(root, address(4));

        rootV2 = anthill.readRecTreeVote(address(1), 0);
        assertEq(rootV2, address(4));

        assert(anthill.readSentTreeVote(address(4)) == address(1));
        assert(anthill.readSentTreeVote(address(5)) == address(4));

        dagConsistencyCheckFrom(anthill, address(4));
        treeConsistencyCheckFrom(address(4));
    }

    //////////////////////////////////////////
    ///////////// utils

    function treeConsistencyCheckFrom(address voter) public {
        for (uint256 i = 0; i < anthill.readRecTreeVoteCount(voter); i++) {
            address recipient = anthill.readRecTreeVote(voter, i);
            if (recipient != address(0)) {
                address sender = anthill.readSentTreeVote(recipient);
                assertEq(sender, voter);
                treeConsistencyCheckFrom(recipient);
            }
        }
    }
}
