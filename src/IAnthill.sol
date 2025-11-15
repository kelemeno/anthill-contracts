// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

struct DagVote {
    address id;
    uint256 weight;
    // distance is always measured to the common ancestor
    // this is to check movements easily,
    // this does not on the other side when a person moves change.
    uint256 dist;
    // position in the other person's sent/rec DagVote array
    // to look up the opposite DagVote, used to calculate depth.
    uint256 posInOther;
}

interface IAnthill {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Events

    event JoinTreeEvent(address voter, string name, address recipient);

    event ChangeNameEvent(address voter, string newName);

    event AddDagVoteEvent(address voter, address recipient, uint256 weight);

    event RemoveDagVoteEvent(address voter, address recipient);

    event LeaveTreeEvent(address voter);

    event SwitchPositionWithParentEvent(address voter);

    event MoveTreeVoteEvent(address voter, address recipient);

    function root() external view returns (address);

    function sentTreeVote(address voter) external view returns (address);

    function recTreeVote(address voter, uint256 posInRecipient) external view returns (address);

    function recTreeVoteCount(address recipient) external view returns (uint256);

    function sentDagVoteCount(address voter) external view returns (uint256);

    function sentDagVote(address voter, uint256 pos) external view returns (address, uint256, uint256, uint256);

    function recDagVoteCount(address recipient) external view returns (uint256);

    function recDagVote(address recipient, uint256 pos) external view returns (address, uint256, uint256, uint256);

    function readSentDagVote(address voter, uint256 pos) external view returns (DagVote memory dagVote);

    function readRecDagVote(address recipient, uint256 pos) external view returns (DagVote memory dagVote);

    function findDistancesRecNotLower(address voter, address recipient) external view returns (bool, uint256, uint256);

    function joinTreeAsRoot(address voter, string calldata name) external;

    function joinTree(address voter, string calldata name, address recipient) external;

    function removeDagVote(address voter, address recipient) external;

    function leaveTree(address voter) external;

    function changeName(address voter, string calldata newName) external;

    function addDagVote(address voter, address recipient, uint256 weight) external;

    function switchPositionWithParent(address voter) external;

    function moveTreeVote(address voter, address recipient) external;

    function findRelDepth(address voter, address recipient) external view returns (bool, uint256);

    function findNthParent(address voter, uint256 n) external view returns (address);

    function findDistAtSameDepth(address voter, address recipient) external view returns (bool, uint256);

    function findSentDagVote(
        address voter,
        address recipient
    ) external view returns (bool, bool, uint256, uint256, uint256, DagVote memory);

    function findRecDagVote(
        address voter,
        address recipient
    ) external view returns (bool, bool, uint256, uint256, uint256, DagVote memory);

    function calculateReputation(address voter) external returns (uint256);
}
