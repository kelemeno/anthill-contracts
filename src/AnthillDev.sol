// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {console} from "forge-std/console.sol";

import {DagVote, Anthill} from "../src/Anthill.sol";
import {TreeVoteExtended, DagVoteExtended, IAnthillDev} from "./IAnthillDev.sol";
import {IAnthill} from "./IAnthill.sol";

contract AnthillDev is IAnthillDev, Anthill {
    uint256 public verbose;

    function setVerbose(uint256 _verbose) public {
        verbose = _verbose;
    }

    function recDagVoteAppendPublic(
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
        nameOf[data.voter] = data.name;
        sentTreeVote[data.voter] = data.recipient;
        recTreeVoteCount[data.voter] = data.recTreeVoteCount;
        recTreeVote[data.recipient][data.posInRecipient] = data.voter;
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

    function unsafeReplaceRecDagVoteWithLastPublic(address recipient, uint256 rPos) public virtual {
        super.unsafeReplaceRecDagVoteWithLast(recipient, rPos);
    }

    ///////////////////////////////////////////////////////////////////////
    /// Logging functions

    function removeTreeVote(address voter) internal virtual override {
        if (verbose > 0) console.log("removeTreeVote", voter);
        super.removeTreeVote(voter);
    }

    function addTreeVote(address voter, address recipient) internal virtual override {
        if (verbose > 0) console.log("addTreeVote", voter, recipient);
        super.addTreeVote(voter, recipient);
    }

    function addTreeVoteWithoutCheck(address voter, address recipient) internal virtual override {
        if (verbose > 0) console.log("addTreeVoteWithoutCheck", voter, recipient);
        super.addTreeVoteWithoutCheck(voter, recipient);
    }

    function switchTreeVoteWithParent(address voter) internal virtual override {
        if (verbose > 0) console.log("switchTreeVoteWithParent", voter);
        super.switchTreeVoteWithParent(voter);
    }

    function joinTree(
        address voter,
        string calldata voterName,
        address recipient
    ) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("joinTree", voter, voterName, recipient);
        super.joinTree(voter, voterName, recipient);
    }

    function joinTreeAsRoot(address voter, string calldata voterName) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("joinTreeAsRoot", voter, voterName);
        super.joinTreeAsRoot(voter, voterName);
    }

    function changeName(address voter, string calldata voterName) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("changeName", voter, voterName);
        super.changeName(voter, voterName);
    }

    function findNthParent(
        address voter,
        uint256 height
    ) public view virtual override(IAnthill, Anthill) returns (address parent) {
        if (verbose > 1) console.log("findNthParent", voter, height);
        return super.findNthParent(voter, height);
    }

    function findRelRoot(address voter) public view virtual override returns (address relRoot, uint256 relDepth) {
        if (verbose > 1) console.log("findRelRoot", voter);
        return super.findRelRoot(voter);
    }

    function findRelDepthInner(
        address voter,
        address recipient
    ) public view virtual override returns (bool isLocal, uint256 sRelRootDiff, uint256 rRelRootDiff) {
        if (verbose > 1) console.log("findRelDepthInner", voter, recipient);
        return super.findRelDepthInner(voter, recipient);
    }

    function findRelDepth(
        address voter,
        address recipient
    ) public view virtual override(IAnthill, Anthill) returns (bool isLocal, uint256 relDepth) {
        if (verbose > 1) console.log("findRelDepth", voter, recipient);
        return super.findRelDepth(voter, recipient);
    }

    function findDistAtSameDepth(
        address add1,
        address add2
    ) public view virtual override(IAnthill, Anthill) returns (bool isSameDepth, uint256 distance) {
        if (verbose > 1) console.log("findDistAtSameDepth", add1, add2);
        return super.findDistAtSameDepth(add1, add2);
    }

    function findDistancesRecNotLower(
        address voter,
        address recipient
    ) public view virtual override(IAnthill, Anthill) returns (bool isLocal, uint256 sDist, uint256 rDist) {
        if (verbose > 0) console.log("findDistancesRecNotLower", voter, recipient);
        return super.findDistancesRecNotLower(voter, recipient);
    }

    function findDistances(
        address voter,
        address recipient
    ) public view virtual override returns (bool isLocal, uint256 sDist, uint256 rDist) {
        if (verbose > 1) console.log("findDistances", voter, recipient);
        return super.findDistances(voter, recipient);
    }

    function addDagVote(address voter, address recipient, uint256 weight) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("addDagVote", voter, recipient, weight);
        super.addDagVote(voter, recipient, weight);
    }

    function removeDagVote(address voter, address recipient) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("removeDagVote", voter, recipient);
        super.removeDagVote(voter, recipient);
    }

    function readDepth(address voter) public view virtual override returns (uint256) {
        if (verbose > 0) console.log("readDepth", voter);
        return super.readDepth(voter);
    }

    function calculateReputation(address voter) public virtual override(IAnthill, Anthill) returns (uint256) {
        if (verbose > 0) console.log("calculateReputation", voter);
        return super.calculateReputation(voter);
    }

    // function clearReputationCalculatedRec(address voter) public virtual override {
    //     if (verbose > 0) console.log("clearReputationCalculatedRec", voter);
    //     super.clearReputationCalculatedRec(voter);
    // }

    function calculateReputationIterative(address voter) public virtual override {
        if (verbose > 0) console.log("calculateReputationIterative", voter);
        super.calculateReputationIterative(voter);
    }

    // function recalculateAllReputation() public virtual override {
    //     if (verbose > 0) console.log("recalculateAllReputation");
    //     super.recalculateAllReputation();
    // }

    function findSentDagVote(
        address voter,
        address recipient
    )
        public
        view
        virtual
        override(IAnthill, Anthill)
        returns (bool votable, bool voted, uint256 sDist, uint256 rDist, uint256 votePos, DagVote memory dagVote)
    {
        if (verbose > 0) console.log("findSentDagVote", voter, recipient);
        return super.findSentDagVote(voter, recipient);
    }

    function findSentDagVoteNew(
        address voter,
        address recipient
    ) public view virtual override returns (bool votable, bool voted, uint256 votePos, DagVote memory dagVote) {
        if (verbose > 0) console.log("findSentDagVoteNew", voter, recipient);
        return super.findSentDagVoteNew(voter, recipient);
    }

    function findRecDagVote(
        address voter,
        address recipient
    )
        public
        view
        virtual
        override(IAnthill, Anthill)
        returns (bool votable, bool voted, uint256 sDist, uint256 rDist, uint256 votePos, DagVote memory dagVote)
    {
        if (verbose > 0) console.log("findRecDagVote", voter, recipient);
        return super.findRecDagVote(voter, recipient);
    }

    function findRecDagVoteNew(
        address voter,
        address recipient
    ) public view virtual override returns (bool votable, bool voted, uint256 votePos, DagVote memory dagVote) {
        if (verbose > 0) console.log("findRecDagVoteNew", voter, recipient);
        return super.findRecDagVoteNew(voter, recipient);
    }

    function combinedDagAppendSdist(
        address voter,
        address recipient,
        uint256 sentDist,
        uint256 recDist,
        uint256 weight
    ) internal virtual override {
        if (verbose > 0) console.log("combinedDagAppendSdist", voter, recipient, sentDist);
        if (verbose > 0) console.log("cont.", recDist, weight);
        super.combinedDagAppendSdist(voter, recipient, sentDist, recDist, weight);
    }

    function unsafeReplaceSentDagVoteWithLast(address voter, uint256 sPos) internal virtual override {
        if (verbose > 1) console.log("unsafeReplaceSentDagVoteWithLast", voter, sPos);
        super.unsafeReplaceSentDagVoteWithLast(voter, sPos);
    }

    function unsafeReplaceRecDagVoteWithLast(address recipient, uint256 rPos) internal virtual override {
        if (verbose > 1) console.log("unsafeReplaceRecDagVoteWithLast", recipient, rPos);
        super.unsafeReplaceRecDagVoteWithLast(recipient, rPos);
    }

    function safeRemoveSentDagVote(address voter, uint256 sPos) internal virtual override {
        if (verbose > 0) console.log("safeRemoveSentDagVote", voter, sPos);
        super.safeRemoveSentDagVote(voter, sPos);
    }

    function safeRemoveRecDagVote(address recipient, uint256 rPos) internal virtual override {
        if (verbose > 0) console.log("safeRemoveRecDagVote", recipient, rPos);
        super.safeRemoveRecDagVote(recipient, rPos);
    }

    function removeAllSentDagVotes(address voter) internal virtual override {
        if (verbose > 0) console.log("removeAllSentDagVotes", voter);
        super.removeAllSentDagVotes(voter);
    }

    function removeAllRecDagVotes(address recipient) internal virtual override {
        if (verbose > 0) console.log("removeAllRecDagVotes", recipient);
        super.removeAllRecDagVotes(recipient);
    }

    function handleDagVoteReplace(
        address voterWithChangingDagVotes,
        address recipient,
        address replacedPositionInTree,
        uint256 sDist,
        uint256 rDist
    ) internal virtual override {
        if (verbose > 0)
            console.log("handleDagVoteReplace", voterWithChangingDagVotes, recipient, replacedPositionInTree);
        if (verbose > 0) console.log("cont.", sDist, rDist);
        super.handleDagVoteReplace(voterWithChangingDagVotes, recipient, replacedPositionInTree, sDist, rDist);

        if (verbose > 0)
            console.log("handleDagVoteReplace finished", voterWithChangingDagVotes, recipient, replacedPositionInTree);
    }

    function pullUpBranch(address pulledVoter, address parent) internal virtual override {
        if (verbose > 0) console.log("pullUpBranch", pulledVoter, parent);
        super.pullUpBranch(pulledVoter, parent);
    }

    function handleLeavingVoterBranch(address voter) internal virtual override {
        if (verbose > 0) console.log("handleLeavingVoterBranch", voter);
        super.handleLeavingVoterBranch(voter);
        if (verbose > 0) console.log("handleLeavingVoterBranch finished", voter);
    }

    function leaveTree(address voter) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("leaveTree", voter);
        super.leaveTree(voter);
    }

    function switchPositionWithParent(address voter) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("switchPositionWithParent", voter);
        super.switchPositionWithParent(voter);
    }

    function moveTreeVote(address voter, address recipient) public virtual override(IAnthill, Anthill) {
        if (verbose > 0) console.log("moveTreeVote", voter, recipient);
        super.moveTreeVote(voter, recipient);
    }

    function test() public {}
}
