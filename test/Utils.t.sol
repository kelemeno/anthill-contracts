// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnthillDev.sol";
import {DagVote} from "../src/Anthill.sol";
import {console} from "forge-std/console.sol";
import {TooManyChildren} from "../src/Errors.sol";

contract Utils is Test {
    function intermediateDagConsistencyCheckFrom(AnthillDev anthill, address voter) public {
        for (uint256 dist = 0; dist < 7; dist++) {
            for (uint256 depth = 1; depth <= dist; depth++) {
                for (uint256 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++) {
                    DagVote memory sDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                    DagVote memory rDagVote = anthill.readRecDagVote(
                        sDagVote.id,
                        dist - depth,
                        depth,
                        sDagVote.posInOther
                    );
                    (bool isLocal, , ) = anthill.findDistancesRecNotLower(voter, sDagVote.id);
                    assert(isLocal);
                    // console.log("id", voter, rDagVote.id, sDagVote.id);
                    assertEq(rDagVote.id, voter);
                    assertEq(rDagVote.weight, sDagVote.weight);
                    assertEq(rDagVote.posInOther, i);
                }

                for (uint256 i = 0; i < anthill.readRecDagVoteCount(voter, dist - depth, depth); i++) {
                    DagVote memory rDagVote = anthill.readRecDagVote(voter, dist - depth, depth, i);
                    DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, dist, depth, rDagVote.posInOther);

                    (bool isLocal, , ) = anthill.findDistancesRecNotLower(rDagVote.id, voter);
                    assert(isLocal);

                    // console.log("voter: ", voter);
                    // console.log( dist, depth, i, rDagVote.id);
                    assertEq(sDagVote.id, voter);
                    assertEq(sDagVote.weight, rDagVote.weight);
                    assertEq(sDagVote.posInOther, i);
                }
            }
        }
        for (uint256 i = 0; i < anthill.readRecTreeVoteCount(voter); i++) {
            intermediateDagConsistencyCheckFrom(anthill, anthill.readRecTreeVote(voter, i));
        }
    }

    function dagConsistencyCheckFrom(AnthillDev anthill, address voter) public {
        for (uint256 i = 0; i < anthill.readSentDagVoteCount(voter, 0, 0); i++) {
            DagVote memory sDagVote = anthill.readSentDagVote(voter, 0, 0, i);
            DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, 0 - 0, 0, sDagVote.posInOther);
            (bool isLocal, uint256 recordedDist, ) = anthill.findDistancesRecNotLower(voter, sDagVote.id);
            assert(isLocal);

            assertEq(rDagVote.id, voter);
            assertEq(rDagVote.weight, sDagVote.weight);
            assertEq(rDagVote.posInOther, i);
            // if (voter == address(16) && sDagVote.id == address(8))
            // {
            //     console.log("voter: ", voter, sDagVote.id);
            //     console.log("i", i);
            //     console.log("distances", sDagVote.dist, rDagVote.dist);
            //     {
            //         (,,,,,DagVote memory vote1) = anthill.findSentDagVote(address(16), address(8));
            //         (,,,,,DagVote memory vote2) = anthill.findSentDagVote(address(32), address(16));
            //         (,,,,,DagVote memory vote3) = anthill.findSentDagVote(address(32), address(8));
            //         console.log(vote1.dist, anthill.readRecDagVote(address(8),0,0,vote1.posInOther).dist, anthill.readRecDagVote(address(8),0,0,vote1.posInOther).id);
            //         console.log(vote2.dist, anthill.readRecDagVote(address(16),0,0,vote2.posInOther).dist, anthill.readRecDagVote(address(16),0,0,vote2.posInOther).id);
            //         console.log(vote3.dist, anthill.readRecDagVote(address(8),0,0,vote3.posInOther).dist, anthill.readRecDagVote(address(8),0,0,vote3.posInOther).id);
            //     }
            // console.log("voter: ", voter, sDagVote.id);
            // console.log(recordedDist, sDagVote.dist);
            // }
            // assertEq(recordedDist, sDagVote.dist);
        }

        for (uint256 i = 0; i < anthill.readRecDagVoteCount(voter, 0 - 0, 0); i++) {
            DagVote memory rDagVote = anthill.readRecDagVote(voter, 0 - 0, 0, i);
            DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, 0, 0, rDagVote.posInOther);

            (bool isLocal, , uint256 recordedRDist) = anthill.findDistancesRecNotLower(rDagVote.id, voter);
            assert(isLocal);

            // console.log("voter: ", voter, recordedDist, 0);
            // console.log( 0, 0, i, rDagVote.id);
            assertEq(sDagVote.id, voter);
            assertEq(sDagVote.weight, rDagVote.weight);
            assertEq(sDagVote.posInOther, i);

            assertEq(recordedRDist, rDagVote.dist);
        }

        for (uint256 i = 0; i < anthill.readRecTreeVoteCount(voter); i++) {
            dagConsistencyCheckFrom(anthill, anthill.readRecTreeVote(voter, i));
        }
    }

    function printRecDagVotes(AnthillDev anthill, address voter) public view {
        uint256 recDagVoteCount = anthill.readRecDagVoteCount(voter, 0, 0);
        for (uint256 i = 0; i < recDagVoteCount; i++) {
            DagVote memory rDagVote = anthill.readRecDagVote(voter, 0, 0, i);
            console.log("rec dag vote: ", voter, 0, 0);
            console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
        }
    }

    function printSentDagVotes(AnthillDev anthill, address voter) public view {
        uint256 dagVoteCount = anthill.readSentDagVoteCount(voter, 0, 0);
        for (uint256 i = 0; i < dagVoteCount; i++) {
            DagVote memory rDagVote = anthill.readSentDagVote(voter, 0, 0, i);
            console.log("sent dag vote: ", voter, 0, 0);
            console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
        }
        console.log("rec dag votes finished");
    }

    function treeConsistencyCheckFrom(Anthill anthill, address voter) public {
        uint256 childCount = anthill.readRecTreeVoteCount(voter);
        if (childCount > 2) {
            revert TooManyChildren(voter, childCount);
        }
        for (uint256 i = 0; i < childCount; i++) {
            address recipient = anthill.readRecTreeVote(voter, i);
            require(recipient != address(0), "child can't be zero");
            address sender = anthill.readSentTreeVote(recipient);
            assertEq(sender, voter);
            treeConsistencyCheckFrom(anthill, recipient);
        }
    }

    function test() public {}
}
