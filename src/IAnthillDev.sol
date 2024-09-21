pragma solidity 0.8.24;

import "./IAnthill.sol";

struct TreeVoteExtended {
    address voter;
    string name;
    address recipient;
    uint256 posInRecipient;
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

interface IAnthillDev is IAnthill {
    function recDagVoteAppendPublic(
        address recipient,
        uint256 recDist,
        uint256,
        address voter,
        uint256 weight,
        uint256
    ) external;

    function handleDagVoteMoveRise(
        address voter,
        address recipient,
        address replaced,
        uint256 distToNewRec,
        uint256 weight
    ) external;

    function handleDagVoteMoveFall(
        address voter,
        address recipient,
        address replaced,
        uint256 distToNewRec,
        uint256 weight
    ) external;

    function setVoterData(TreeVoteExtended calldata data) external;

    function setDagVote(DagVoteExtended calldata data) external;

    function unsafeReplaceRecDagVoteWithLastPublic(address recipient, uint256 rPos) external;
}