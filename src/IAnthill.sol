// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IAnthill {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Events

    event ChangeNameEvent(address voter, string newName);

    event AddDagVoteEvent(address voter, address recipient, uint256 weight);

    event RemoveDagVoteEvent(address voter, address recipient);

    event LeaveTreeEvent(address voter);

    event SwitchPositionWithParentEvent(address voter);

    event MoveTreeVoteEvent(address voter, address recipient);
}
