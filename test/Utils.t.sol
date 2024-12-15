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
                for (uint256 i = 0; i < anthill.sentDagVoteCount(voter); i++) {
                    (address s_id, uint256 s_weight, , uint256 s_posInOther) = anthill.sentDagVote(voter, i);
                    (address r_id, uint256 r_weight, , uint256 r_posInOther) = anthill.recDagVote(s_id, s_posInOther);
                    (bool isLocal, , ) = anthill.findDistancesRecNotLower(voter, s_id);
                    assert(isLocal);
                    // console.log("id", voter, rDagVote.id, sDagVote.id);
                    assertEq(r_id, voter);
                    assertEq(r_weight, s_weight);
                    assertEq(r_posInOther, i);
                }

                for (uint256 i = 0; i < anthill.recDagVoteCount(voter); i++) {
                    (address r_id, uint256 r_weight, , uint256 r_posInOther) = anthill.recDagVote(voter, i);
                    (address s_id, uint256 s_weight, , uint256 s_posInOther) = anthill.sentDagVote(r_id, r_posInOther);

                    (bool isLocal, , ) = anthill.findDistancesRecNotLower(r_id, voter);
                    assert(isLocal);

                    // console.log("voter: ", voter);
                    // console.log( dist, depth, i, rDagVote.id);
                    assertEq(s_id, voter);
                    assertEq(s_weight, r_weight);
                    assertEq(s_posInOther, i);
                }
            }
        }
        for (uint256 i = 0; i < anthill.recTreeVoteCount(voter); i++) {
            intermediateDagConsistencyCheckFrom(anthill, anthill.recTreeVote(voter, i));
        }
    }

    function dagConsistencyCheckFrom(IAnthillDev anthill, address voter) public {
        console.log("dagConsistencyCheckFrom", voter);
        for (uint256 i = 0; i < anthill.sentDagVoteCount(voter); i++) {
            uint256 failCase = 0;
            DagVote memory sDagVote = anthill.readSentDagVote(voter, i);
            DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, sDagVote.posInOther);
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
                console.log(anthill.sentTreeVote(voter));
                console.log(anthill.findNthParent(voter, 2));
                revert DagConsistencyCheckFailed(failCase, voter, sDagVote.id, i);
            }
        }

        for (uint256 i = 0; i < anthill.recDagVoteCount(voter); i++) {
            (address r_id, uint256 r_weight, uint256 r_dist, uint256 r_posInOther) = anthill.recDagVote(voter, i);
            (address s_id, uint256 s_weight, uint256 s_dist, uint256 s_posInOther) = anthill.sentDagVote(
                r_id,
                r_posInOther
            );

            (bool isLocal, uint256 recordedDist, uint256 recordedRDist) = anthill.findDistancesRecNotLower(r_id, voter);
            assert(isLocal && recordedDist != recordedRDist);

            // console.log("voter: ", voter, recordedDist, 0);
            // console.log( 0, 0, i, rDagVote.id);
            assertEq(s_id, voter);
            assertEq(s_weight, r_weight);
            assertEq(s_posInOther, i);

            assertEq(recordedRDist, r_dist);
        }

        for (uint256 i = 0; i < anthill.recTreeVoteCount(voter); i++) {
            dagConsistencyCheckFrom(anthill, anthill.recTreeVote(voter, i));
        }
    }

    function printRecDagVotes(IAnthillDev anthill, address voter) public view {
        uint256 recDagVoteCount = anthill.recDagVoteCount(voter);
        for (uint256 i = 0; i < recDagVoteCount; i++) {
            (address r_id, uint256 r_weight, uint256 r_dist, uint256 r_posInOther) = anthill.recDagVote(voter, i);
            console.log("rec dag vote: ", voter);
            console.log(i, r_id, r_weight, r_posInOther);
        }
    }

    function printSentDagVotes(IAnthillDev anthill, address voter) public view {
        uint256 dagVoteCount = anthill.sentDagVoteCount(voter);
        for (uint256 i = 0; i < dagVoteCount; i++) {
            (address s_id, uint256 s_weight, uint256 s_dist, uint256 s_posInOther) = anthill.sentDagVote(voter, i);
            console.log("sent dag vote: ", voter);
            console.log(i, s_id, s_weight, s_posInOther);
        }
        console.log("sent dag votes finished");
    }

    function treeConsistencyCheckFromInner(IAnthillDev anthill, address voter) public {
        uint256 childCount = anthill.recTreeVoteCount(voter);
        if (childCount > 2) {
            revert TooManyChildren(voter, childCount);
        }
        for (uint256 i = 0; i < childCount; i++) {
            address recipient = anthill.recTreeVote(voter, i);
            require(recipient != address(0), "child can't be zero");
            address sender = anthill.sentTreeVote(recipient);
            assertEq(sender, voter);
        }
        // for (uint256 i = 0; i < childCount; i++) {
        //     address recipient = anthill.recTreeVote(voter, i);
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
        uint256 sentDagVoteCount = anthill.sentDagVoteCount(voter);
        for (uint256 i = 0; i < sentDagVoteCount; i++) {
            (address r_id, , , ) = anthill.recDagVote(voter, i);
            callback(anthill, r_id);
        }
    }

    function crawlRecDagVotes(
        IAnthillDev anthill,
        address voter,
        function(IAnthillDev, address) internal callback
    ) internal {
        uint256 recDagVoteCount = anthill.recDagVoteCount(voter);
        for (uint256 i = 0; i < recDagVoteCount; i++) {
            (address r_id, , , ) = anthill.recDagVote(voter, i);
            callback(anthill, r_id);
        }
    }

    function recursiveCrawlTree(
        IAnthillDev anthill,
        address voter,
        function(IAnthillDev, address) internal callback
    ) internal {
        callback(anthill, voter);
        for (uint256 i = 0; i < anthill.recTreeVoteCount(voter); i++) {
            recursiveCrawlTree(anthill, anthill.recTreeVote(voter, i), callback);
        }
    }

    function test() public {}
}
