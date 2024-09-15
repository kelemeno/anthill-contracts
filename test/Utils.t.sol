// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Anthill2Dev.sol";
import {DagVote} from "../src/Anthill2.sol";
import {console} from "forge-std/console.sol";

contract Utils is Test {
    function intermediateDagConsistencyCheckFrom(Anthill2Dev anthill, address voter) public {
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

    function dagConsistencyCheckFrom(Anthill2Dev anthill, address voter) public {
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

    function printRecDagVotes(Anthill2Dev anthill, address voter) public view {
        for (uint256 dist = 0; dist < 7; dist++) {
            for (uint256 depth = 0; depth <= 7; depth++) {
                for (uint256 i = 0; i < anthill.readRecDagVoteCount(voter, dist, depth); i++) {
                    DagVote memory rDagVote = anthill.readRecDagVote(voter, dist, depth, i);
                    console.log("rec dag vote: ", voter, dist, depth);
                    console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
                }
            }
        }
    }

    function printSentDagVotes(Anthill2Dev anthill, address voter) public view {
        for (uint256 dist = 0; dist < 7; dist++) {
            for (uint256 depth = 0; depth <= 7; depth++) {
                for (uint256 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++) {
                    DagVote memory rDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                    console.log("sent dag vote: ", voter, dist, depth);
                    console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
                }
            }
        }
        console.log("rec dag votes finished");
    }

    function treeConsistencyCheckFrom(Anthill2 anthill, address voter) public {
        for (uint256 i = 0; i < anthill.readRecTreeVoteCount(voter); i++) {
            address recipient = anthill.readRecTreeVote(voter, i);
            if (recipient != address(0)) {
                address sender = anthill.readSentTreeVote(recipient);
                assertEq(sender, voter);
                treeConsistencyCheckFrom(anthill, recipient);
            }
        }
    }
}
