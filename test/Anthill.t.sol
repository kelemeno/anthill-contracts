// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnthillDev.sol";
import {DagVote} from "../src/Anthill.sol";
import {console} from "forge-std/console.sol";
import {Utils} from "./Utils.t.sol";

// for testing uncomment modifiers, and comment msg.sender checks out
// until then test are also commented out.

contract AnthillTestMain is Test, Utils {
    AnthillDev public anthill;

    function setUp() public {
        anthill = new AnthillDev();

        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));

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

    /////////////////////////////////////////////
    /////////// personal and local checks
    function testRelDepth() public {
        (bool isLocal, uint256 depth) = anthill.findRelDepth(address(4), address(5));
        assertEq(depth, 0);
        assert(isLocal);
    }

    function testReadRoot() public {
        address a = anthill.readRoot();
        assertEq(a, address(2));
    }

    function testParents() public {
        address a = anthill.readSentTreeVote(anthill.readSentTreeVote(anthill.readSentTreeVote(address(23))));
        assertEq(a, address(2));
    }

    function testFindRelDepth() public {
        (, uint256 depth) = anthill.findRelDepth(address(8), address(5));
        assertEq(depth, 1);
    }

    function testFindNthParent() public {
        address voteA = anthill.findNthParent(address(8), 1);
        assertEq(voteA, address(4));
    }

    function testFindDistAtSameDepth() public {
        (bool isLocal, uint256 dist) = anthill.findDistAtSameDepth(address(4), address(5));
        assertEq(1, dist);
        assert(isLocal);
    }

    /////////////////////////////////////////////
    /////////// basic dag tests
    function testFindSentDagVote2() public {
        (, bool voted, , , uint256 votePos, ) = anthill.findSentDagVote(address(8), address(5));
        assertEq(votePos, 2);
        // assertEq(dist, 2);
        // assertEq(depth, 1);
        assertEq(voted, true);
    }

    function testAddAndRemoveDagVote1() public {
        anthill.removeDagVote(address(8), address(5));
        anthill.addDagVote(address(8), address(5), 1);
        (, bool voted, uint256 dist, uint256 depth, , ) = anthill.findSentDagVote(address(8), address(5));
        assertEq(voted, true);
        // assertEq(dist, 2);
        // assertEq(depth, 1);

        (, voted, dist, depth, , ) = anthill.findRecDagVote(address(8), address(5));
        assertEq(voted, true);
        // assertEq(dist, 1);
        // assertEq(depth, 1);

        anthill.removeDagVote(address(8), address(5));
        (, voted, dist, depth, , ) = anthill.findSentDagVote(address(8), address(5));
        assertEq(voted, false);

        (, voted, dist, depth, , ) = anthill.findRecDagVote(address(8), address(5));
        assertEq(voted, false);
    }

    function testAddAndRemoveDagVote2() public {
        // anthill.addDagVote(address(34),address(9), 1);
        (, bool voted, uint256 dist, uint256 depth, , ) = anthill.findSentDagVote(address(34), address(9));
        assertEq(voted, true);
        assertEq(dist, 3);
        // assertEq(depth, 2);

        (, voted, , dist, , ) = anthill.findRecDagVote(address(34), address(9));
        assertEq(voted, true);
        assertEq(dist, 1);
        // assertEq(depth, 2);

        anthill.removeDagVote(address(34), address(9));
        (, voted, dist, depth, , ) = anthill.findSentDagVote(address(34), address(9));
        assertEq(voted, false);

        (, voted, dist, depth, , ) = anthill.findRecDagVote(address(34), address(9));
        assertEq(voted, false);
    }

    /////////////////////////////////////////////
    ////////// Dag internal tests
    /////////////////////////////////////////
    /////////// single votes
    function testChangeDistDepthRec() public {
        (, bool voted, uint256 rdist, uint256 depth, uint256 votePos, DagVote memory rDagVote) = anthill.findRecDagVote(
            address(16),
            address(4)
        );
        assertEq(voted, true);
        // assertEq(rdist, 0);
        // assertEq(depth, 2);
        assertEq(votePos, 4);

        anthill.unsafeReplaceRecDagVoteWithLastPublic(address(4), 0);

        uint256 count = anthill.readRecDagVoteCount(address(4), 0, 2);
        assertEq(count, 27);
        count = anthill.readSentDagVoteCount(address(16), 3, 2);
        assertEq(count, 7);

        anthill.recDagAppendPublic(
            address(4),
            1,
            2,
            address(16),
            rDagVote.weight,
            anthill.readSentDagVoteCount(address(16), 3, 2)
        );
        count = anthill.readRecDagVoteCount(address(4), 1, 2);
        assertEq(count, 28);

        count = anthill.readSentDagVoteCount(address(16), 3, 2);
        assertEq(count, 7);

        // anthill.changeDistDepthSent(address(16), 2, 2, rDagVote.posInOther, 3, 2, address(4), anthill.readRecDagVoteCount(address(4), 1, 2)-1, rDagVote.weight);
        // count = anthill.readRecDagVoteCount(address(4), 1, 2);
        // assertEq(count, 5);
        // count = anthill.readSentDagVoteCount(address(16), 3, 2);
        // assertEq(count, 2);
        // intermediatedagConsistencyCheckFrom( anthill, address(2));
    }

    ////////////////////////////////////////
    /////////// combined square handlers

    function testHandleDagVoteMoveRise() public {
        anthill.handleDagVoteMoveRise(address(4), address(1), address(2), 2, 2);

        intermediateDagConsistencyCheckFrom(anthill, address(2));
    }

    ///////////////////////////////////////////
    /////////// E2E tests

    function testCalculateRep() public {
        uint256 rep = anthill.calculateReputation(address(4));
        uint256 rep2 = anthill.calculateReputation(address(2));
        console.log(rep);
        console.log(rep2);

        // these tests are commented out in the original, why are the correct values
        // assert(rep  +100- 3000000000000000000< 1000);
        // assert(rep2 +100- 1000000000000000000< 1000);
    }

    function testSwitchPositionWithParent1() public {
        address root = anthill.readRoot();
        assertEq(root, address(2));

        anthill.switchPositionWithParent(address(4));
        root = anthill.readRoot();
        assertEq(root, address(4));

        assert(anthill.readSentTreeVote(address(16)) == address(8));
        assert(anthill.readSentTreeVote(address(8)) == address(2));
        assert(anthill.readSentTreeVote(address(2)) == address(4));
        assert(anthill.readSentTreeVote(address(10)) == address(5));
        assert(anthill.readSentTreeVote(address(5)) == address(4));

        intermediateDagConsistencyCheckFrom(anthill, address(2));
        dagConsistencyCheckFrom(anthill, address(4));
        treeConsistencyCheckFrom(anthill, address(4));
    }

    function testSwitchPositionWithParent2() public {
        // todo
        for (uint160 i = 32; i < 48; i++) {
            anthill.removeDagVote(address(i), address(16));
        }
        anthill.moveTreeVote(address(33), address(32));
        anthill.addDagVote(address(33), address(32), 100000000);
        anthill.switchPositionWithParent(address(32));
        address parent = anthill.readSentTreeVote(address(16));
        assertEq(parent, address(32));
        dagConsistencyCheckFrom(anthill, address(2));
        treeConsistencyCheckFrom(anthill, address(2));
    }

    function testLeaveTree() public {
        // {
        //     (,,,,,DagVote memory vote1) = anthill.findSentDagVote(address(16), address(8));
        //     (,,,,,DagVote memory vote2) = anthill.findSentDagVote(address(32), address(16));
        //     (,,,,,DagVote memory vote3) = anthill.findSentDagVote(address(32), address(8));
        //     console.log(vote1.dist, anthill.readRecDagVote(address(8),0,0,vote1.posInOther).dist);
        //     console.log(vote2.dist, anthill.readRecDagVote(address(16),0,0,vote2.posInOther).dist);
        //     console.log(vote3.dist, anthill.readRecDagVote(address(8),0,0,vote3.posInOther).dist);
        // }
        // dagConsistencyCheckFrom( anthill, address(2));

        anthill.leaveTree(address(4));

        // for 2
        address recipient = anthill.readRecTreeVote(address(2), 0);
        assertEq(recipient, address(8));

        recipient = anthill.readRecTreeVote(address(2), 1);
        assertEq(recipient, address(5));

        recipient = anthill.readSentTreeVote(address(8));
        assertEq(recipient, address(2));

        // for 8

        recipient = anthill.readRecTreeVote(address(8), 0);
        assertEq(recipient, address(16));

        recipient = anthill.readRecTreeVote(address(8), 1);
        assertEq(recipient, address(9));

        recipient = anthill.readSentTreeVote(address(9));
        assertEq(recipient, address(8));

        recipient = anthill.readSentTreeVote(address(16));
        assertEq(recipient, address(8));

        // for 16

        recipient = anthill.readRecTreeVote(address(16), 0);
        assertEq(recipient, address(32));

        recipient = anthill.readRecTreeVote(address(16), 1);
        assertEq(recipient, address(17));

        recipient = anthill.readSentTreeVote(address(17));
        assertEq(recipient, address(16));

        recipient = anthill.readSentTreeVote(address(32));
        assertEq(recipient, address(16));

        // // for 32

        recipient = anthill.readRecTreeVote(address(32), 0);
        assertEq(recipient, address(33));

        recipient = anthill.readRecTreeVote(address(32), 1);
        assertEq(recipient, address(0));

        recipient = anthill.readSentTreeVote(address(33));
        assertEq(recipient, address(32));

        dagConsistencyCheckFrom(anthill, address(2));
        treeConsistencyCheckFrom(anthill, address(2));
    }

    function testMoveInTree1() public {
        anthill.moveTreeVote(address(16), address(32));
        dagConsistencyCheckFrom(anthill, address(2));
        treeConsistencyCheckFrom(anthill, address(2));
    }

    function testMoveInTree2() public {
        anthill.moveTreeVote(address(16), address(40));
        dagConsistencyCheckFrom(anthill, address(2));
        treeConsistencyCheckFrom(anthill, address(2));
    }

    function testMoveInTree3() public {
        anthill.moveTreeVote(address(32), address(40));
        anthill.moveTreeVote(address(32), address(16));
        dagConsistencyCheckFrom(anthill, address(2));
        treeConsistencyCheckFrom(anthill, address(2));
    }

    function testConsistency() public {
        treeConsistencyCheckFrom(anthill, address(2));
        dagConsistencyCheckFrom(anthill, address(2));
    }
}
