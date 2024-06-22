// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DagVote, Anthill2} from "../src/Anthill2.sol";

contract Anthill2Dev is Anthill2 {
    function recDagAppendPublic(
        address recipient,
        uint256 recDist,
        uint256,
        address voter,
        uint256 weight,
        uint256 sPos
    ) public onlyUnlocked {
        recDagVote[recipient][recDagVoteCount[recipient]] = DagVote({
            id: voter,
            weight: weight,
            dist: recDist,
            posInOther: sentDagVoteCount[voter] - 1
        });
        ++(recDagVoteCount[recipient]);
    }

    function handleDagVoteMoveRise(
        address voter,
        address recipient,
        address replaced,
        uint256 distToNewRec,
        uint256 depthToNewRec
    ) public onlyUnlocked {
        handleDagVoteReplace(voter, recipient, replaced, distToNewRec, distToNewRec - depthToNewRec);
    }

    function handleDagVoteMoveFall(
        address voter,
        address recipient,
        address replaced,
        uint256 distToNewRec,
        uint256 depthToNewRec
    ) public onlyUnlocked {
        handleDagVoteReplace(voter, recipient, replaced, distToNewRec, distToNewRec + depthToNewRec);
    }
}
