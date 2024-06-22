// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import {console} from "forge-std/console.sol";
import {IAnthill} from "./IAnthill.sol";

struct DagVote {
    address id;
    uint256 weight;
    // this is to check movements easily, this does not often change.
    uint256 dist;
    // to look up the opposite DagVote, used to calculate depth.
    uint256 posInOther;
}

contract Anthill2 is IAnthill {
    constructor() {
        decimalPoint = 18;
        MAX_REL_ROOT_DEPTH = 6;
    }

    modifier onlyVoter(address voter) {
        if (!unlocked) {
            require(msg.sender == voter, "AntH: only voter");
        }
        _;
    }

    modifier onlyUnlocked() {
        require(unlocked, "AntH: only unlocker");
        _;
    }

    function lockTree() public {
        if (unlocked) {
            unlocked = false;
        }
    }

    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// State variables
    bool public unlocked = true;

    string public tokenName = "Anthill";
    string public tokenSymbol = "ANTH";

    uint256 public decimalPoint; // total weight of each voter should be 1, but we don't have floats, so we use 10**18.
    uint256 public MAX_REL_ROOT_DEPTH;
    /// todo: maybe have root be recTreeVote[address(1)][0] instead of a separate variable.
    address public root;

    mapping(address => string) names;
    mapping(address => address) treeVote;

    mapping(address => uint256) recTreeVoteCount;
    mapping(address => mapping(uint256 => address)) recTreeVote;

    mapping(address voter => uint256 count) sentDagVoteCount;
    mapping(address voter => mapping(uint256 counter => DagVote vote)) sentDagVote;
    mapping(address => uint256) sentDagVoteTotalWeight;

    mapping(address voter => uint256 count) recDagVoteCount;
    mapping(address voter => mapping(uint256 counter => DagVote vote)) recDagVote;

    mapping(address => uint256) reputation;
    mapping(address => bool) repIsCalculated;

    function decimals() public view returns (uint256) {
        return decimalPoint;
    }

    function name() public view returns (string memory) {
        return tokenName;
    }

    function symbol() public view returns (string memory) {
        return tokenSymbol;
    }

    function balanceOf(address voter) public view returns (uint256) {
        return readReputation(voter);
    }

    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree internal
    function removeTreeVote(address voter) internal {
        address recipient = treeVote[voter];
        uint256 votePos = recTreeVote[recipient][0] == voter ? 0 : 1;

        recTreeVote[recipient][votePos] = recTreeVote[recipient][recTreeVoteCount[recipient] - 1];
        recTreeVote[recipient][recTreeVoteCount[recipient] - 1] = address(0);
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] - 1;

        // this sets it to one =1, but removeTreeVote is always temporary, there is always only a single root, and a single voter with treeVote =1 .
        treeVote[voter] = address(1);
    }

    function addTreeVote(address voter, address recipient) internal {
        require(recTreeVoteCount[recipient] < 2, "Ai, aDV 2");
        addTreeVoteWithoutCheck(voter, recipient);
    }

    function addTreeVoteWithoutCheck(address voter, address recipient) internal {
        require(treeVote[voter] == address(1), "Ai, aTVWC 1");

        treeVote[voter] = recipient;

        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;
    }

    // this switches the position of a voter and its parent, without considering the
    function switchTreeVoteWithParent(address voter) internal {
        address parent = treeVote[voter];
        require(parent != address(0), "Ai, sTVWP 1");
        require(parent != address(1), "Ai, sTVWP 2");

        address gparent = treeVote[parent]; // this can be 1.

        removeTreeVote(voter);

        if (readRoot() == parent) {
            root = voter;
        } else {
            removeTreeVote(parent);
        }

        address brother = recTreeVote[parent][0];

        address child1 = recTreeVote[voter][0];
        address child2 = recTreeVote[voter][1];

        addTreeVoteWithoutCheck(voter, gparent);
        addTreeVoteWithoutCheck(parent, voter);

        if (brother != address(0)) {
            removeTreeVote(brother);
            addTreeVoteWithoutCheck(brother, voter);
        }

        if (child1 != address(0)) {
            removeTreeVote(child1);
            addTreeVoteWithoutCheck(child1, parent);
        }

        if (child2 != address(0)) {
            removeTreeVote(child2);
            addTreeVoteWithoutCheck(child2, parent);
        }
    }

    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree externals

    // when we first join the tree
    function joinTree(address voter, string calldata voterName, address recipient) public onlyVoter(voter) {
        require(treeVote[voter] == address(0), "A lT 2");
        require(treeVote[recipient] != address(0), "A lT 3");
        require(recTreeVoteCount[recipient] < 2, "A lT 4");

        treeVote[voter] = recipient;
        names[voter] = voterName;
        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;

        addDagVote(voter, recipient, 1);

        emit joinTreeEvent(voter, voterName, recipient);
    }

    // when we first join the tree without a parent
    function joinTreeAsRoot(address voter, string calldata voterName) public onlyVoter(voter) {
        require(treeVote[voter] == address(0), "A jTAR 2");
        require(root == address(0), "A jTAR 3");

        names[voter] = voterName;
        treeVote[voter] = address(1);
        root = voter;
        recTreeVote[address(1)][0] = voter;
        recTreeVoteCount[address(1)] = 1;
    }

    function changeName(address voter, string calldata voterName) public onlyVoter(voter) {
        require(treeVote[voter] != address(0), "A jTAR 5");
        names[voter] = voterName;

        emit changeNameEvent(voter, voterName);
    }
    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Local tree finders

    /// ~MRRD
    function findNthParent(address voter, uint256 height) public view returns (address parent) {
        if (height == 0) {
            return voter;
        }

        if (treeVote[voter] == address(1)) {
            return address(1);
        }

        // this should never be the case, but it is a safety check
        require(treeVote[voter] != address(0), "Ai, fNP 1");

        return findNthParent(treeVote[voter], height - 1);
    }

    // to find voters relative root, = the highest ancestor of the voter (including the voter) under MAX_REL_ROOT_DEPTH
    function findRelRoot(address voter) public view returns (address relRoot, uint256 relDepth) {
        require(treeVote[voter] != address(0), "Ai, fRR 1");

        relRoot = voter;
        address parent;

        for (relDepth = 0; relDepth < MAX_REL_ROOT_DEPTH; relDepth++) {
            parent = treeVote[relRoot];
            if (parent == address(1)) {
                break;
            }
            relRoot = parent;
        }
        return (relRoot, relDepth);
    }

    // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative root
    // the recipient cannot be lower than the voter ( equality ok )
    function findRelDepthInner(
        address voter,
        address recipient
    ) public view returns (bool isLocal, uint256 relRootDiff, uint256 rDist) {
        if ((treeVote[voter] == address(0)) || (treeVote[recipient] == address(0))) {
            return (false, 0, 0);
        }

        address relRoot;
        (relRoot, relRootDiff) = findRelRoot(voter);
        address recipientAncestor = recipient;

        for (uint256 i = 0; i <= relRootDiff; i++) {
            if (recipientAncestor == relRoot) {
                return (true, relRootDiff, i);
            }

            recipientAncestor = treeVote[recipientAncestor];

            if (recipientAncestor == address(0)) {
                return (false, 0, 0);
            }
        }
        return (false, 0, 0);
    }

    function findRelDepth(address voter, address recipient) public view returns (bool isLocal, uint256 relDepth) {
        uint256 relRootDiff;
        uint256 rDist;

        (isLocal, relRootDiff, rDist) = findRelDepthInner(voter, recipient);
        relDepth = relRootDiff - rDist;
    }

    // to find the distance between voter and recipient, within maxDistance.
    // THIS IS ACTUALLY A GLOBAL FUNTION!
    function findDistAtSameDepth(address add1, address add2) public view returns (bool isSameDepth, uint256 distance) {
        if (add1 == add2) {
            return (true, 0);
        }

        if (treeVote[add1] == address(0) || treeVote[add2] == address(0)) {
            return (false, 0);
        }

        if (treeVote[add1] == address(1) || treeVote[add2] == address(1)) {
            return (false, 0);
        }

        (isSameDepth, distance) = findDistAtSameDepth(treeVote[add1], treeVote[add2]);

        if (isSameDepth) {
            return (true, distance + 1);
        }

        return (false, 0);
    }

    // to find the distance and depth from a voter to recipient. Note, the recipient has to be higher and in the neighbourhood of the voter.
    function findDistancesRecNotLower(
        address voter,
        address recipient
    ) public view returns (bool isLocal, uint256 sDist, uint256 rDist) {
        if (treeVote[voter] == address(0) || treeVote[recipient] == address(0)) {
            return (false, 0, 0);
        }

        uint256 relDepth;
        (isLocal, relDepth) = findRelDepth(voter, recipient);
        if (!isLocal) {
            return (false, 0, 0);
        }

        address voterAnscenstor = findNthParent(voter, relDepth);
        uint256 distance;
        (, distance) = findDistAtSameDepth(voterAnscenstor, recipient);

        return (isLocal, distance + relDepth, distance);
    }

    function findDistances(
        address voter,
        address recipient
    ) public view returns (bool isLocal, uint256 sDist, uint256 rDist) {
        if (treeVote[voter] == address(0) || treeVote[recipient] == address(0)) {
            return (false, 0, 0);
        }

        bool voterIsLocal;
        bool recipientIsLocal;
        uint256 voterRelRootDiff;
        uint256 recipientRelRootDiff;
        uint256 sDistRelRoot;
        uint256 rDistRelRoot;

        (voterIsLocal, voterRelRootDiff, rDistRelRoot) = findRelDepthInner(voter, recipient);
        (recipientIsLocal, recipientRelRootDiff, sDistRelRoot) = findRelDepthInner(recipient, voter);
        isLocal = voterIsLocal && recipientIsLocal;
        sDist = voterRelRootDiff + rDistRelRoot;
        rDist = recipientRelRootDiff + sDistRelRoot; // todo check this is correct
    }

    //////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag personal externals
    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    function addDagVote(address voter, address recipient, uint256 weight) public onlyVoter(voter) {
        (bool votable, bool voted, uint256 sDist, uint256 rDist, , ) = findSentDagVote(voter, recipient);
        require((votable) && (!voted), "A aDV 2");
        combinedDagAppendSdist(voter, recipient, sDist, rDist, weight);

        emit addDagVoteEvent(voter, recipient, weight);
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public onlyVoter(voter) {
        // find the votes we delete
        (bool votable, bool voted, uint256 sPos, ) = findSentDagVoteNew(voter, recipient);
        require(voted, "A rDV 2");

        safeRemoveSentDagVote(voter, sPos);

        emit removeDagVoteEvent(voter, recipient);
    }

    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global readers

    function readDepth(address voter) public view returns (uint256) {
        if (treeVote[voter] == address(0)) return 0;
        if (treeVote[voter] == address(1)) return 0;

        return readDepth(treeVote[voter]) + 1;
    }

    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Reputation Related

    // to calculate the reputation of a voter, i.e. the sum of the votes of the voter and all its descendants
    // not efficient
    function calculateReputation(address voter) public returns (uint256) {
        uint256 voterReputation = 0;
        if (voter == address(0)) return 0;

        for (uint256 count = 0; count < recDagVoteCount[voter]; count++) {
            DagVote memory rDagVote = recDagVote[voter][count];
            voterReputation +=
                (calculateReputation(rDagVote.id) * (rDagVote.weight)) /
                sentDagVoteTotalWeight[rDagVote.id];
        }

        // for the voter themselves
        voterReputation += 10 ** decimalPoint;
        reputation[voter] = voterReputation;
        return voterReputation;
    }

    function clearReputationCalculatedRec(address voter) public {
        if (readSentTreeVote(voter) == address(0)) {
            return;
        }

        repIsCalculated[voter] = false;

        for (uint256 count = 0; count < recTreeVoteCount[voter]; count++) {
            clearReputationCalculatedRec(recTreeVote[voter][count]);
        }
    }

    // Todo: redo: we need to rely on external ordered calls
    function calculateReputationRec(address voter) public {
        if (readSentTreeVote(voter) == address(0)) {
            return;
        }

        if (repIsCalculated[voter]) {
            return;
        }

        for (uint256 count = 0; count < recTreeVoteCount[voter]; count++) {
            calculateReputationRec(recTreeVote[voter][count]);
        }

        uint256 voterReputation = 0;
        for (uint256 count = 0; count < recDagVoteCount[voter]; count++) {
            DagVote memory rDagVote = recDagVote[voter][count];
            voterReputation += (reputation[rDagVote.id] * (rDagVote.weight)) / sentDagVoteTotalWeight[rDagVote.id];
        }

        voterReputation += 10 ** decimalPoint;
        reputation[voter] = voterReputation;

        repIsCalculated[voter] = true;
    }

    function recalculateAllReputation() public {
        clearReputationCalculatedRec(root);
        calculateReputationRec(root);
    }
    ////////////////////////////////////////////
    //// DAG finders
    // to check the existence and to find the position of a vote in the sentDagVote array

    function findSentDagVote(
        address voter,
        address recipient
    )
        public
        view
        returns (bool votable, bool voted, uint256 sDist, uint256 rDist, uint256 votePos, DagVote memory dagVote)
    {
        (votable, sDist, rDist) = findDistancesRecNotLower(voter, recipient);

        if ((!votable) || (sDist == rDist)) {
            return (false, false, 0, 0, 0, DagVote(address(0), 0, 0, 0));
        }

        for (uint256 i = 0; i < sentDagVoteCount[voter]; i++) {
            DagVote memory sDagVote = sentDagVote[voter][i];
            if (sDagVote.id == recipient) {
                return (true, true, sDist, rDist, i, sDagVote);
            }
        }

        return (true, false, sDist, rDist, 0, DagVote(address(0), 0, 0, 0));
    }

    function findSentDagVoteNew(
        address voter,
        address recipient
    ) public view returns (bool votable, bool voted, uint256 votePos, DagVote memory dagVote) {
        (votable, voted, , , votePos, dagVote) = findSentDagVote(voter, recipient);
    }

    function findRecDagVote(
        address voter,
        address recipient
    )
        public
        view
        returns (bool votable, bool voted, uint256 sdist, uint256 depth, uint256 votePos, DagVote memory dagVote)
    {
        bool isLocal;
        uint256 sDist;
        uint256 rDist;

        // todo
        (isLocal, sDist, rDist) = findDistancesRecNotLower(voter, recipient);

        if ((!isLocal) || (sDist == rDist)) {
            return (false, false, 0, 0, 0, DagVote(address(0), 0, 0, 0));
        }

        for (uint256 i = 0; i < recDagVoteCount[recipient]; i++) {
            DagVote memory rDagVote = recDagVote[recipient][i];
            if (rDagVote.id == voter) {
                return (true, true, sDist, rDist, i, rDagVote);
            }
        }

        return (true, false, sDist, rDist, 0, DagVote(address(0), 0, 0, 0));
    }

    // to check the existence and to find the position of a vote the recDagVote array
    function findRecDagVoteNew(
        address voter,
        address recipient
    ) public view returns (bool votable, bool voted, uint256 votePos, DagVote memory dagVote) {
        (votable, voted, , , votePos, dagVote) = findRecDagVote(voter, recipient);
    }

    ////////////////////////////////////////////
    //// Dag internals.
    ///////////// Single vote changes

    function combinedDagAppendSdist(
        address voter,
        address recipient,
        uint256 sentDist,
        uint256 recDist,
        uint256 weight
    ) internal {
        sentDagVote[voter][sentDagVoteCount[voter]] = DagVote({
            id: recipient,
            weight: weight,
            dist: sentDist,
            posInOther: recDagVoteCount[recipient]
        });
        ++(sentDagVoteCount[voter]);
        sentDagVoteTotalWeight[voter] += weight;
        recDagVote[recipient][recDagVoteCount[recipient]] = DagVote({
            id: voter,
            weight: weight,
            dist: recDist,
            posInOther: sentDagVoteCount[voter] - 1
        });
        ++(recDagVoteCount[recipient]);
    }

    ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.

    // careful does not delete the opposite! Always call with opposite, or do something with the other vote
    function unsafeReplaceSentDagVoteWithLast(address voter, uint256 sPos) internal {
        // find the vote we delete
        DagVote memory sDagVote = sentDagVote[voter][sPos];
        sentDagVoteTotalWeight[voter] -= sDagVote.weight;

        if (sPos != sentDagVoteCount[voter] - 1) {
            // if we delete a vote in the middle, we need to copy the last vote to the deleted position
            DagVote memory copiedSentDagVote = sentDagVote[voter][sentDagVoteCount[voter] - 1];
            sentDagVote[voter][sPos] = DagVote({
                id: copiedSentDagVote.id,
                weight: copiedSentDagVote.weight,
                dist: copiedSentDagVote.dist,
                posInOther: copiedSentDagVote.posInOther
            });
            recDagVote[copiedSentDagVote.id][copiedSentDagVote.posInOther].posInOther = sPos;
        }

        // delete the potentially copied hence duplicate last vote
        delete sentDagVote[voter][sentDagVoteCount[voter] - 1];
        --sentDagVoteCount[voter];
    }

    /// careful, does not delete the opposite!
    function unsafeReplaceRecDagVoteWithLast(address recipient, uint256 rPos) public {
        require(unlocked, "A uSRDV 1");
        if (rPos != recDagVoteCount[recipient] - 1) {
            DagVote memory copiedRecDagVote = recDagVote[recipient][recDagVoteCount[recipient] - 1];
            recDagVote[recipient][rPos] = DagVote({
                id: copiedRecDagVote.id,
                weight: copiedRecDagVote.weight,
                dist: copiedRecDagVote.dist,
                posInOther: copiedRecDagVote.posInOther
            });
            sentDagVote[copiedRecDagVote.id][copiedRecDagVote.posInOther].posInOther = rPos;
        }

        // delete the the potentially copied hence duplicate last vote
        delete recDagVote[recipient][recDagVoteCount[recipient] - 1];
        --recDagVoteCount[recipient];
    }

    function safeRemoveSentDagVote(address voter, uint256 sPos) internal {
        DagVote memory sDagVote = sentDagVote[voter][sPos];
        unsafeReplaceSentDagVoteWithLast(voter, sPos);
        // delete the opposite
        unsafeReplaceRecDagVoteWithLast(sDagVote.id, sDagVote.posInOther);
    }

    function safeRemoveRecDagVote(address recipient, uint256 rPos) internal {
        DagVote memory rDagVote = recDagVote[recipient][rPos];
        unsafeReplaceRecDagVoteWithLast(recipient, rPos);
        // delete the opposite
        unsafeReplaceSentDagVoteWithLast(rDagVote.id, rDagVote.posInOther);
    }

    ///////////// Personal changers

    function removeAllSentDagVotes(address voter) public {
        uint256 count = sentDagVoteCount[voter];
        for (uint256 i = count; 0 < i; --i) {
            safeRemoveSentDagVote(voter, i - 1);
        }
    }

    function removeAllRecDagVotes(address recipient) public {
        uint256 count = recDagVoteCount[recipient];
        for (uint256 i = count; 0 < i; --i) {
            safeRemoveRecDagVote(recipient, i - 1);
        }
    }

    // function sortRecDagVoteDescendants(address recipient, address replaced) public {
    //     // here dist is 1, as we are sorting the descendant from our brother's desdcendant
    //     for (uint256 i = recDagVoteCount[recipient]; 0 < i; i--) {
    //         DagVote memory rDagVote = recDagVote[recipient][i - 1];
    //         if (rDagVote.dist == 0){
    //             DagVote memory sDagVote = sentDagVote[rDagVote.id][rDagVote.posInOther];
    //             address anscestorAtDepth = findNthParent(rDagVote.id, sDagVote.dist);

    //             if (anscestorAtDepth == replaced) {
    //                 // recDagVote[recipient][i-1].dist = 1;
    //                 // sentDagVote[rDagVote.id][rDagVote.posInOther].dist = ;
    //                 // safeRemoveRecDagVoteAtDistDepthPos( dag , recipient, 1, depth, i-1);
    //                 // combinedDagAppendSdist( dag , rDagVote.id, recipient, depth, depth, rDagVote.weight);
    //             }
    //         }
    //     }
    // }

    /// here we are replacing the replaced, keeping our old dagVotes.
    /// the voter address,
    /// the recipient of the new tree Vote, ( we need this case if replaced = 0, otherwise it is the replaced treeVote)
    /// replace is if we are switching positions with a voter, in this case the dist in DagVote becomes 0 for new descendants, and stops being 0 for the old now non-descendants.
    /// note we don't care about where we come from
    function handleDagVoteReplace(
        address voterWithChangingDagVotes,
        address recipient,
        address replacedPositionInTree,
        uint256 sDistToNewRec,
        uint256 rDistForNewRec
    ) public onlyUnlocked {
        address temp = address(99999999);

        if (replacedPositionInTree == address(0)) {
            treeVote[temp] = address(1);
            addTreeVote(temp, recipient);
            replacedPositionInTree = temp;
        }

        uint256 count = sentDagVoteCount[voterWithChangingDagVotes];
        for (uint256 i = count; 0 < i; --i) {
            DagVote memory sDagVote = sentDagVote[voterWithChangingDagVotes][i - 1];
            (bool isLocal, uint256 sDist, uint256 rDist) = findDistancesRecNotLower(
                replacedPositionInTree,
                sDagVote.id
            );
            if (!isLocal) {
                safeRemoveSentDagVote(voterWithChangingDagVotes, i - 1);
                continue;
            } else {
                sentDagVote[voterWithChangingDagVotes][i - 1].dist = sDist;
                recDagVote[sDagVote.id][sDagVote.posInOther].dist = rDist;
            }
        }

        count = recDagVoteCount[voterWithChangingDagVotes];
        for (uint256 i = count; 0 < i; --i) {
            DagVote memory rDagVote = recDagVote[voterWithChangingDagVotes][i - 1];
            (bool isLocal, uint256 sDist, uint256 rDist) = findDistancesRecNotLower(
                rDagVote.id,
                replacedPositionInTree
            );
            if (!isLocal) {
                safeRemoveRecDagVote(voterWithChangingDagVotes, i - 1);
                continue;
            } else {
                recDagVote[voterWithChangingDagVotes][i - 1].dist = rDist;
                sentDagVote[rDagVote.id][rDagVote.posInOther].dist = sDist;
            }
        }

        if (replacedPositionInTree == temp) {
            removeTreeVote(temp);
        }
        // else {
        //     sortRecDagVoteDescendants(voterWithChangingDagVotes, replacedPositionInTree);
        // }
    }

    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global internal

    //// This is recursive, we pull up the branch of the first child, handling the tree votes and changed dag votes in the process
    function pullUpBranch(address pulledVoter, address parent) internal {
        require(unlocked, "A pUB");
        // we fist handle the dag structure, using the tree structure, then we change the tree votes.

        // if (readRecTreeVoteCount(pulledVoter)==0) return;
        address firstChild = readRecTreeVote(pulledVoter, 0);
        address secondChild = readRecTreeVote(pulledVoter, 1);
        if (firstChild != address(0)) {
            handleDagVoteReplace(firstChild, parent, pulledVoter, 2, 0);

            pullUpBranch(firstChild, pulledVoter);

            if (secondChild != address(0)) {
                removeTreeVote(secondChild);
                addTreeVote(secondChild, firstChild);
            }
        }
    }

    /// here the strategy is: pull up the branch of the first child, and handle the leaving voter edge case
    function handleLeavingVoterBranch(address voter) internal {
        require(unlocked, "A hLVB");

        // we fist handle the dag structure, using the tree structure, then we change the tree votes.
        address parent = treeVote[voter];

        address firstChild = recTreeVote[voter][0];
        address secondChild = recTreeVote[voter][1];

        if (firstChild != address(0)) {
            handleDagVoteReplace(firstChild, parent, voter, 2, 0);

            pullUpBranch(firstChild, voter);

            if (secondChild != address(0)) {
                removeTreeVote(secondChild);
                addTreeVote(secondChild, firstChild);
            }

            removeTreeVote(firstChild);
            addTreeVoteWithoutCheck(firstChild, parent);
        }

        removeTreeVote(voter);
        treeVote[voter] = address(1);

        if (root == voter) {
            root = firstChild;
        }
    }
    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global external
    //// Note
    //// there is no general strategy for handling changes to the graph:
    //// We only deal with special cases, where we can predict how the graph will change.
    //// Leave tree, pull up branch
    //// Move to empty position (similar to leave, just keeps some votes)
    //// Switch position with parent ( only movement is with parent)
    //// In the future we can add:
    //// Switch with random person
    //// Move subgroup
    //// Further notes
    //// We can often optimise by removing out of range dagVotes first
    //// the general strategy
    //// for arbitrary changes:
    //// would be to check for each moved voter their dagVotes if it is in range for the new tree,
    //// if yes change the distance.
    ////

    function leaveTree(address voter) public onlyVoter(voter) {
        removeAllSentDagVotes(voter);
        removeAllRecDagVotes(voter);

        handleLeavingVoterBranch(voter);
        treeVote[voter] = address(0);

        emit leaveTreeEvent(voter);
    }

    function switchPositionWithParent(address voter) public onlyVoter(voter) {
        address parent = treeVote[voter];
        require(parent != address(0), "A lT 3");
        require(parent != address(1), "A lT 4");
        address gparent = treeVote[parent];

        uint256 voterRep = calculateReputation(voter);
        uint256 parentRep = calculateReputation(parent);

        require(voterRep > parentRep, "A lT 5");

        handleDagVoteReplace(parent, parent, voter, 0, 0);
        handleDagVoteReplace(voter, gparent, parent, 2, 0);

        switchTreeVoteWithParent(voter);

        emit switchPositionWithParentEvent(voter);
    }

    /// the strategy here is we remove the mover, create the new tree strcuture, check Dag structure, and add him back.
    function moveTreeVote(address voter, address recipient) external onlyVoter(voter) {
        {
            require(treeVote[voter] != address(0), "A mTV 2");
            require(treeVote[recipient] != address(0), "A mTV 3");
            require(recTreeVoteCount[recipient] < 2, "A mTV 4");
        }
        (bool isLocal, uint256 sDist, uint256 rDist) = findDistances(voter, recipient);
        {
            // we need to leave the tree nowm so that our descendants can rise.
            address parent = treeVote[voter];
            handleLeavingVoterBranch(voter);

            if ((sDist == 0) && (isLocal)) {
                // if we are jumping to our descendant who just rose, we have to modify the rDist
                if (findNthParent(recipient, rDist) == parent) {
                    rDist = rDist - 1;
                }
            }
        }

        // currently we don't support position swithces here, so replaced address is always 0.
        if (isLocal) {
            handleDagVoteReplace(voter, recipient, address(0), sDist, rDist);
        } else {
            // we completely jumped out. remove all dagVotes.
            removeAllSentDagVotes(voter);
            removeAllRecDagVotes(voter);
        }

        // handle tree votes
        // there is a single twist here, if recipient is the descendant of the voter that rises. todo is this a problem?
        addTreeVote(voter, recipient);

        emit moveTreeVoteEvent(voter, recipient);
    }

    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Legacy
    //////// Variable readers
    // root/base
    function readRoot() public view returns (address) {
        return root;
    }

    function readMaxRelRootDepth() public view returns (uint256) {
        return MAX_REL_ROOT_DEPTH;
    }

    // for node properties
    function readReputation(address voter) public view returns (uint256) {
        return reputation[voter];
    }

    function readName(address voter) public view returns (string memory) {
        return names[voter];
    }

    // for tree votes
    function readSentTreeVote(address voter) public view returns (address) {
        return treeVote[voter];
    }

    function readRecTreeVoteCount(address recipient) public view returns (uint256) {
        return recTreeVoteCount[recipient];
    }

    function readRecTreeVote(address recipient, uint256 votePos) public view returns (address) {
        return recTreeVote[recipient][votePos];
    }

    // for sent dag

    function readSentDagVoteDistDiff(address voter) external view returns (uint256) {
        return 0;
    }

    function readSentDagVoteDepthDiff(address voter) external view returns (uint256) {
        return 0;
    }

    function readSentDagVoteCount(address voter, uint256, uint256) public view returns (uint256) {
        return sentDagVoteCount[voter];
    }

    function readSentDagVote(address voter, uint256, uint256, uint256 votePos) public view returns (DagVote memory) {
        return sentDagVote[voter][votePos];
    }

    function readSentDagVoteTotalWeight(address voter) public view returns (uint256) {
        return sentDagVoteTotalWeight[voter];
    }

    // for rec Dag votes

    function readRecDagVoteDistDiff(address recipient) external view returns (uint256) {
        return 0;
    }

    function readRecDagVoteDepthDiff(address recipient) public view returns (uint256) {
        return 0;
    }

    function readRecDagVoteCount(address recipient, uint256 rdist, uint256 depth) public view returns (uint256) {
        return recDagVoteCount[recipient];
    }

    function readRecDagVote(address recipient, uint256, uint256, uint256 votePos) public view returns (DagVote memory) {
        return recDagVote[recipient][votePos];
    }
}
