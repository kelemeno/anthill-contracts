// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DagVote, Anthill} from "../src/Anthill.sol";

struct TreeVoteExtended {
    address voter;
    string name;
    address sentTreeVote;
    uint256 recTreeVoteCount;
    uint256 sentDagVoteCount;
    uint256 sentDagVoteTotalWeight;
    uint256 recDagVoteCount;
}

struct DagVoteExtended {
    address voter;
    address recipient;
    uint256 weight;
    uint256 sDist;
    uint256 rDist;
    uint256 posInVoter;
    uint256 posInRecipient;
}

contract AnthillDev is Anthill {
    function recDagAppendPublic(
        address recipient,
        uint256 recDist,
        uint256,
        address voter,
        uint256 weight,
        uint256 
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

    function setVoterData(TreeVoteExtended calldata data) public onlyUnlocked {
        names[data.voter] = data.name;
        treeVote[data.voter] = data.sentTreeVote;
        recTreeVoteCount[data.voter] = data.recTreeVoteCount;
        sentDagVoteCount[data.voter] = data.sentDagVoteCount;
        sentDagVoteTotalWeight[data.voter] = data.sentDagVoteTotalWeight;
        recDagVoteCount[data.voter] = data.recDagVoteCount;
    }

    function setDagVote(DagVoteExtended calldata data) public onlyUnlocked {
        sentDagVote[data.voter][data.posInVoter] = DagVote({
            id: data.recipient,
            weight: data.weight,
            dist: data.sDist,
            posInOther: data.posInRecipient
        });
        recDagVote[data.recipient][data.posInRecipient] = DagVote({
            id: data.voter,
            weight: data.weight,
            dist: data.rDist,
            posInOther: data.posInVoter
        });
    }
}
