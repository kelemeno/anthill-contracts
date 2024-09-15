// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {console} from "forge-std/console.sol";

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

    function unsafeReplaceRecDagVoteWithLastPublic(address recipient, uint256 rPos) public virtual {
        super.unsafeReplaceRecDagVoteWithLast(recipient, rPos);
    }



    ///////////////////////////////////////////////////////////////////////
    /// Logging functions

    function removeTreeVote(address voter) internal virtual override {
        console.log("removeTreeVote", voter);
        super.removeTreeVote(voter);
    }

    function addTreeVote(address voter, address recipient) internal virtual override {
        console.log("addTreeVote", voter, recipient);
        super.addTreeVote(voter, recipient);
    }

    function addTreeVoteWithoutCheck(address voter, address recipient) internal virtual override {
        console.log("addTreeVoteWithoutCheck", voter, recipient);
        super.addTreeVoteWithoutCheck(voter, recipient);
    }

    function switchTreeVoteWithParent(address voter) internal virtual override {
        console.log("switchTreeVoteWithParent", voter);
        super.switchTreeVoteWithParent(voter);
    }

    function joinTree(address voter, string calldata voterName, address recipient) public virtual override {
        console.log("joinTree", voter, voterName, recipient);
        super.joinTree(voter, voterName, recipient);
    }

    function joinTreeAsRoot(address voter, string calldata voterName) public virtual override {
        console.log("joinTreeAsRoot", voter, voterName);
        super.joinTreeAsRoot(voter, voterName);
    }

    function changeName(address voter, string calldata voterName) public virtual override {
        console.log("changeName", voter, voterName);
        super.changeName(voter, voterName);
    }

    function findNthParent(address voter, uint256 height) public view virtual override returns (address parent) {
        console.log("findNthParent", voter, height);
        return super.findNthParent(voter, height);
    }

    function findRelRoot(address voter) public view virtual override returns (address relRoot, uint256 relDepth) {
        console.log("findRelRoot", voter);
        return super.findRelRoot(voter);
    }

    function findRelDepthInner(address voter, address recipient) public view virtual override returns (bool isLocal, uint256 sRelRootDiff, uint256 rRelRootDiff) {
        console.log("findRelDepthInner", voter, recipient);
        return super.findRelDepthInner(voter, recipient);
    }

    function findRelDepth(address voter, address recipient) public view virtual override returns (bool isLocal, uint256 relDepth) {
        console.log("findRelDepth", voter, recipient);
        return super.findRelDepth(voter, recipient);
    }

    function findDistAtSameDepth(address add1, address add2) public view virtual override returns (bool isSameDepth, uint256 distance) {
        console.log("findDistAtSameDepth", add1, add2);
        return super.findDistAtSameDepth(add1, add2);
    }

    function findDistancesRecNotLower(address voter, address recipient) public view virtual override returns (bool isLocal, uint256 sDist, uint256 rDist) {
        console.log("findDistancesRecNotLower", voter, recipient);
        return super.findDistancesRecNotLower(voter, recipient);
    }

    function findDistances(address voter, address recipient) public view virtual override returns (bool isLocal, uint256 sDist, uint256 rDist) {
        console.log("findDistances", voter, recipient);
        return super.findDistances(voter, recipient);
    }

    function addDagVote(address voter, address recipient, uint256 weight) public virtual override {
        console.log("addDagVote", voter, recipient, weight);
        super.addDagVote(voter, recipient, weight);
    }

    function removeDagVote(address voter, address recipient) public virtual override {
        console.log("removeDagVote", voter, recipient);
        super.removeDagVote(voter, recipient);
    }

    function readDepth(address voter) public view virtual override returns (uint256) {
        console.log("readDepth", voter);
        return super.readDepth(voter);
    }

    function calculateReputation(address voter) public virtual override returns (uint256) {
        console.log("calculateReputation", voter);
        return super.calculateReputation(voter);
    }

    function clearReputationCalculatedRec(address voter) public virtual override {
        console.log("clearReputationCalculatedRec", voter);
        super.clearReputationCalculatedRec(voter);
    }

    function calculateReputationRec(address voter) public virtual override {
        console.log("calculateReputationRec", voter);
        super.calculateReputationRec(voter);
    }

    function recalculateAllReputation() public virtual override {
        console.log("recalculateAllReputation");
        super.recalculateAllReputation();
    }

    function findSentDagVote(address voter, address recipient) public view virtual override returns (bool votable, bool voted, uint256 sDist, uint256 rDist, uint256 votePos, DagVote memory dagVote) {
        console.log("findSentDagVote", voter, recipient);
        return super.findSentDagVote(voter, recipient);
    }

    function findSentDagVoteNew(address voter, address recipient) public view virtual override returns (bool votable, bool voted, uint256 votePos, DagVote memory dagVote) {
        console.log("findSentDagVoteNew", voter, recipient);
        return super.findSentDagVoteNew(voter, recipient);
    }

    function findRecDagVote(address voter, address recipient) public view virtual override returns (bool votable, bool voted, uint256 sDist, uint256 rDist, uint256 votePos, DagVote memory dagVote) {
        console.log("findRecDagVote", voter, recipient);
        return super.findRecDagVote(voter, recipient);
    }

    function findRecDagVoteNew(address voter, address recipient) public view virtual override returns (bool votable, bool voted, uint256 votePos, DagVote memory dagVote) {
        console.log("findRecDagVoteNew", voter, recipient);
        return super.findRecDagVoteNew(voter, recipient);
    }
    
    function combinedDagAppendSdist(
        address voter,
        address recipient,
        uint256 sentDist,
        uint256 recDist,
        uint256 weight
    ) internal virtual override {
        console.log("combinedDagAppendSdist", voter, recipient, sentDist);
        console.log("cont.", recDist, weight);
        super.combinedDagAppendSdist(voter, recipient, sentDist, recDist, weight);
    }

    function unsafeReplaceSentDagVoteWithLast(address voter, uint256 sPos) internal virtual override {
        console.log("unsafeReplaceSentDagVoteWithLast", voter, sPos);
        super.unsafeReplaceSentDagVoteWithLast(voter, sPos);
    }

    function unsafeReplaceRecDagVoteWithLast(address recipient, uint256 rPos) internal virtual override {
        console.log("unsafeReplaceRecDagVoteWithLast", recipient, rPos);
        super.unsafeReplaceRecDagVoteWithLast(recipient, rPos);
    }

    function safeRemoveSentDagVote(address voter, uint256 sPos) internal virtual override {
        console.log("safeRemoveSentDagVote", voter, sPos);
        super.safeRemoveSentDagVote(voter, sPos);
    }

    function safeRemoveRecDagVote(address recipient, uint256 rPos) internal virtual override {
        console.log("safeRemoveRecDagVote", recipient, rPos);
        super.safeRemoveRecDagVote(recipient, rPos);
    }

    function removeAllSentDagVotes(address voter) public virtual override {
        console.log("removeAllSentDagVotes", voter);
        super.removeAllSentDagVotes(voter);
    }

    function removeAllRecDagVotes(address recipient) public virtual override {
        console.log("removeAllRecDagVotes", recipient);
        super.removeAllRecDagVotes(recipient);
    }

    function handleDagVoteReplace(
        address voterWithChangingDagVotes,
        address recipient,
        address replacedPositionInTree,
        uint256 sDist,
        uint256 rDist
    ) public virtual override {
        console.log("handleDagVoteReplace", voterWithChangingDagVotes, recipient, replacedPositionInTree);
        console.log("cont.", sDist, rDist);
        super.handleDagVoteReplace(voterWithChangingDagVotes, recipient, replacedPositionInTree, sDist, rDist);
    }

    function pullUpBranch(address pulledVoter, address parent) internal virtual override {
        console.log("pullUpBranch", pulledVoter, parent);
        super.pullUpBranch(pulledVoter, parent);
    }

    function handleLeavingVoterBranch(address voter) internal virtual override {
        console.log("handleLeavingVoterBranch", voter);
        super.handleLeavingVoterBranch(voter);
    }

    function leaveTree(address voter) public virtual override {
        console.log("leaveTree", voter);
        super.leaveTree(voter);
    }

    function switchPositionWithParent(address voter) public virtual override {
        console.log("switchPositionWithParent", voter);
        super.switchPositionWithParent(voter);
    }

    function moveTreeVote(address voter, address recipient) public virtual override {
        console.log("moveTreeVote", voter, recipient);
        super.moveTreeVote(voter, recipient);
    }

}
