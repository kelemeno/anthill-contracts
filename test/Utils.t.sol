// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnthillDev.sol";
import {DagVote} from "../src/Anthill.sol";
import {console} from "forge-std/console.sol";
import {TooManyChildren, DagConsistencyCheckFailed} from "../src/Errors.sol";
import {IAnthillDev} from "../src/IAnthillDev.sol";

contract Utils is Test {
    function intermediateDagConsistencyCheckFrom(IAnthillDev anthill, address voter) public {
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

    function dagConsistencyCheckFrom(IAnthillDev anthill, address voter) public {
        console.log("dagConsistencyCheckFrom", voter);
        for (uint256 i = 0; i < anthill.readSentDagVoteCount(voter, 0, 0); i++) {
            uint256 failCase = 0;
            DagVote memory sDagVote = anthill.readSentDagVote(voter, 0, 0, i);
            DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, 0 - 0, 0, sDagVote.posInOther);
            (bool isLocal, uint256 recordedDist, uint256 recordedRDist) = anthill.findDistancesRecNotLower(
                voter,
                sDagVote.id
            );

            if (!(isLocal && recordedDist != recordedRDist)) {
                failCase = 1;
            }

            failCase = (rDagVote.id == voter) ? 0 : 2;
            failCase = (rDagVote.weight == sDagVote.weight) ? failCase : 3;
            failCase = (rDagVote.posInOther == i) ? failCase : 4;
            failCase = (recordedDist == sDagVote.dist) ? failCase : 5;
            if (failCase != 0) {
                console.log(i);
                console.log(recordedDist, sDagVote.dist);
                console.log(anthill.readSentTreeVote(voter));
                console.log(anthill.findNthParent(voter, 2));
                revert DagConsistencyCheckFailed(failCase, voter, sDagVote.id, i);
            }
        }

        for (uint256 i = 0; i < anthill.readRecDagVoteCount(voter, 0 - 0, 0); i++) {
            DagVote memory rDagVote = anthill.readRecDagVote(voter, 0 - 0, 0, i);
            DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, 0, 0, rDagVote.posInOther);

            (bool isLocal, uint256 recordedDist, uint256 recordedRDist) = anthill.findDistancesRecNotLower(
                rDagVote.id,
                voter
            );
            assert(isLocal && recordedDist != recordedRDist);

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

    function printRecDagVotes(IAnthillDev anthill, address voter) public view {
        uint256 recDagVoteCount = anthill.readRecDagVoteCount(voter, 0, 0);
        for (uint256 i = 0; i < recDagVoteCount; i++) {
            DagVote memory rDagVote = anthill.readRecDagVote(voter, 0, 0, i);
            console.log("rec dag vote: ", voter);
            console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
        }
    }

    function printSentDagVotes(IAnthillDev anthill, address voter) public view {
        uint256 dagVoteCount = anthill.readSentDagVoteCount(voter, 0, 0);
        for (uint256 i = 0; i < dagVoteCount; i++) {
            DagVote memory rDagVote = anthill.readSentDagVote(voter, 0, 0, i);
            console.log("sent dag vote: ", voter);
            console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
        }
        console.log("sent dag votes finished");
    }

    function treeConsistencyCheckFromInner(IAnthillDev anthill, address voter) public {
        uint256 childCount = anthill.readRecTreeVoteCount(voter);
        if (childCount > 2) {
            revert TooManyChildren(voter, childCount);
        }
        for (uint256 i = 0; i < childCount; i++) {
            address recipient = anthill.readRecTreeVote(voter, i);
            require(recipient != address(0), "child can't be zero");
            address sender = anthill.readSentTreeVote(recipient);
            assertEq(sender, voter);
        }
        // for (uint256 i = 0; i < childCount; i++) {
        //     address recipient = anthill.readRecTreeVote(voter, i);
        //     treeConsistencyCheckFrom(anthill, recipient);
        // }
    }

    function treeConsistencyCheckFrom(IAnthillDev anthill, address voter) public {
        recursiveCrawlTree(anthill, voter, treeConsistencyCheckFromInner);
    }

    function crawlSentDagVotes(
        IAnthillDev anthill,
        address voter,
        function(IAnthillDev, address) internal callback
    ) internal {
        uint256 sentDagVoteCount = anthill.readSentDagVoteCount(voter, 0, 0);
        for (uint256 i = 0; i < sentDagVoteCount; i++) {
            DagVote memory rDagVote = anthill.readRecDagVote(voter, 0, 0, i);
            callback(anthill, rDagVote.id);
        }
    }

    function crawlRecDagVotes(
        IAnthillDev anthill,
        address voter,
        function(IAnthillDev, address) internal callback
    ) internal {
        uint256 recDagVoteCount = anthill.readRecDagVoteCount(voter, 0, 0);
        for (uint256 i = 0; i < recDagVoteCount; i++) {
            DagVote memory rDagVote = anthill.readRecDagVote(voter, 0, 0, i);
            callback(anthill, rDagVote.id);
        }
    }

    function recursiveCrawlTree(
        IAnthillDev anthill,
        address voter,
        function(IAnthillDev, address) internal callback
    ) internal {
        callback(anthill, voter);
        for (uint256 i = 0; i < anthill.readRecTreeVoteCount(voter); i++) {
            recursiveCrawlTree(anthill, anthill.readRecTreeVote(voter, i), callback);
        }
    }

    function test() public {}
}
