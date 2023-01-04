// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Anthill {

    event SimpleEventForUpdates(uint256 randint);

////////////////////////////
//// State variables
    uint256 public MAX_REL_ROOT_DEPTH =6;

    mapping(address => address) public treeVote;

    mapping(address => uint256) public recTreeVoteCount;
    mapping(address => mapping(uint256 => address)) public recTreeVote;

    mapping(address => uint256) public sentDagVoteDiff;
    mapping(address => mapping(uint256 => uint256)) public sentDagVoteCount;
    mapping(address => mapping(uint256 => mapping(uint256 => address))) public sentDagVote;

    mapping(address => uint256) public recDagVoteDiff;
    mapping(address => mapping(uint256 => uint256)) public recDagVoteCount;
    mapping(address => mapping(uint256 => mapping(uint256 => address))) public recDagVote;

////////////////////////////////////////
/////// Variable readers 


    function readMaxRelRootDepth() public view returns(uint256){
        return MAX_REL_ROOT_DEPTH;
    }

    function readTreeVote(address voter) public view returns(address){
    return treeVote[voter];
    }

    function readRecTreeVoteCount(address recipient) public view returns(uint256){
            return recTreeVoteCount[recipient];
    }

    function readRecTreeVote(address recipient, uint256 votePos) public view returns(address){
            return recTreeVote[recipient][votePos];
    }

    function readSentDagVoteDiff(address voter) public view returns(uint256){
            return sentDagVoteDiff[voter];
    }

    function readSentDagVoteCount(address voter, uint256 heightDiff) public view returns(uint256){
            return sentDagVoteCount[voter][heightDiff];
    }

    function readSentDagVote(address voter, uint256 heightDiff, uint256 votePos) public view returns(address){
            return sentDagVote[voter][heightDiff][votePos];
    }

    function readRecDagVoteDiff(address voter) public view returns(uint256){
            return recDagVoteDiff[voter];
    }

    function readRecDagVoteCount(address voter, uint256 heightDiff) public view returns(uint256){
            return recDagVoteCount[voter][heightDiff];
    }

    function readRecDagVote(address voter, uint256 heightDiff, uint256 votePos) public view returns(address){
            return recDagVote[voter][heightDiff][votePos];
    }

////////////////////////////////////////
//// Neighbour tree externals


    // when we first join the tree
    function joinTree(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);

        assert (treeVote[voter] == address(0));

        assert (treeVote[recipient] != address(0));
        treeVote[voter] = recipient;

        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;
    }

    // when we first join the tree without a parent
    function joinTreeAsRoot(address voter) public {
        emit SimpleEventForUpdates(1);

        assert (treeVote[voter] == address(0));
        treeVote[voter] = address(1);
    }

////////////////////////////////////////
//// Neighbour tree finder/internals    
    function findRecTreeVotePos(address voter, address recipient) public view returns (bool voted, uint256 votePos) {
        for (uint256 i = 0; i < recTreeVoteCount[recipient]; i++) {
            if (recTreeVote[recipient][i] == voter) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    //// we should add public version of this
    function removeTreeVote(address voter) internal {
        address recipient = treeVote[voter];
        (, uint256 votePos) = findRecTreeVotePos(voter, recipient);

        recTreeVote[recipient][votePos] = recTreeVote[recipient][recTreeVoteCount[recipient]-1];
        recTreeVote[recipient][recTreeVoteCount[recipient]-1]= address(0);
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] - 1;

        treeVote[voter] = address(1);
    }

    /// we should add public version of this
    function addTreeVote(address voter, address recipient) internal {
        assert (treeVote[voter] == address(1));
        treeVote[voter] = recipient;

        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;
    }

////////////////////////////////////////////////////////////////////////
//// Local tree finders

    // to find our relative root, our ancestor at depth MAX_REL_ROOT_DEPTH
    function findRelRoot(address voter) public view returns (address relRoot, uint256 relRootDiff){
        assert (treeVote[voter] != address(0));

        relRoot = voter;
        address parent;
        uint256 relRootDiff;

        for (relRootDiff = 0; relRootDiff < MAX_REL_ROOT_DEPTH; relRootDiff++) {
            parent = treeVote[relRoot];
            if (parent == address(1)) {
                break;
            }
            relRoot = parent;
        }
        return (relRoot, relRootDiff);
    }

    // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative root
    function findDepthDiff(address voter, address recipient) public view returns (bool isLocal, uint256 depthDiff){
        
        if ((treeVote[voter] == address(0)) || (treeVote[recipient] == address(0))) {
            return (false, 0);
        }

        (address relRoot, uint256 relRootDiff) = findRelRoot(voter);
        address recipientAncestor = recipient;

        for (uint256 i = 0; i < relRootDiff; i++) {
            if (recipientAncestor == relRoot) {
                return (true, relRootDiff-i);
            }
            
            recipientAncestor = treeVote[recipientAncestor];

            if (recipientAncestor == address(1)) {
                return (false, 0);
            }
        }
        return (false, 0);
    }

    // to find the distance between two voters at the same depth if that distance in under maxdistance
    function findDistance(address add1, address add2, uint256 maxDistance) public view returns (bool isLocal, uint256 distance) {
        if ( treeVote[add1] == address(0) || treeVote[add2] == address(0)) {
            return (false, 0);
        }

        if (treeVote[add1] == address(1) || treeVote[add2] == address(1)) {
            return (false, 0);
        }
        
        if (add1 == add2){
            return (true, 0);
        }

        if (maxDistance == 0) {
            return (false, 0);
        }

        (isLocal, distance) = findDistance(treeVote[add1], treeVote[add2], maxDistance -1);

        // we could remove this check and return isLocal, distance + 1
        if (isLocal == true) {
            return (true, distance + 1);
        }

        return (false, 0);
    }


////////////////////////////////////////////////////////////////////////
//// DAG finders
    // to check the existence and to find the position of a vote in a given row of the sentDagVote array
    function findSentDagVotePosAtDepth(address voter, address recipient, uint256 depth) public view returns (bool voted, uint256 votePos){
        
        uint256  diff = sentDagVoteDiff[voter];

        for (uint256 i = 0; i < sentDagVoteCount[voter][diff+depth] ; i++) {

            if (sentDagVote[voter][diff+depth][i] == recipient) {
                return (true, i);
            }
        }

        return (false, 0);

    }

    // to check the existence and to find the position of a vote in a given row of the recDagVote array
    function findRecDagVotePosAtDepth(address voter, address recipient, uint256 depth) public view returns (bool voted, uint256 votePos){
        
        uint256  diff = recDagVoteDiff[recipient];

        for (uint256 i = 0; i < recDagVoteCount[recipient][diff+depth] ; i++) {
            if (recDagVote[recipient][diff+depth][i] == voter) {
                return (true, i);
            }
        }
        
        return (false, 0);
    }

    // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
    function findSentDagVote(address voter, address recipient) public view returns (bool voted, uint256 depthDiff, uint256 votePos){ 
        (bool votable, uint256 depthDiff) = findDepthDiff(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0);
        }

        (voted,  votePos) = findSentDagVotePosAtDepth(voter, recipient, depthDiff);

        return (voted, depthDiff, votePos);
    }

    // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position, votePos is column pos)
    function findRecDagVote(address voter, address recipient) public view returns (bool voted, uint256 depthDiff, uint256 votePos){
        (bool votable, uint256 depthDiff) = findDepthDiff(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0);
        }

        (voted, votePos) = findRecDagVotePosAtDepth(voter, recipient, depthDiff);

        return (voted, depthDiff, votePos);
    }


////////////////////////////////////////////////////////////////////////
//// Dag externals
    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    function addDagVote(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);

        (bool voted, uint256 depthDiff, ) = findSentDagVote(voter, recipient);
        assert (voted == false);

        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]] = recipient;
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] += 1;

        recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff]] = voter;
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff] += 1;        
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);
        (bool voted, uint256 depthDiff, uint256 votePos) = findSentDagVote(voter, recipient);
        assert (voted == true);

        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][votePos] = sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]-1];
        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]-1]= address(0);
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] -= 1;

        (bool recVoted, uint256 recDepthDiff, uint256 recVotePos) = findRecDagVote(voter, recipient);
        assert (recVoted == true);

        recDagVote[recipient][recDagVoteDiff[recipient]+recDepthDiff][recVotePos] = recDagVote[recipient][recDagVoteDiff[recipient]+recDepthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff]-1];
        recDagVote[recipient][recDagVoteDiff[recipient]+recDepthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff]-1] = address(0);

        recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff] -= 1;
    }


////////////////////////////////////////////////////////////////////////
//// Dag internals

    // to remove a row of votes from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteRow(address voter, uint256 depth) internal {
        for (uint256 i = 0; i < sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth]; i++) {
            // find recipient and position in recDagVote array
            address recipient = sentDagVote[voter][sentDagVoteDiff[voter]+depth][i];
            (, uint256 recVotePos) = findRecDagVotePosAtDepth(voter, recipient, depth);
            // remove from recDagVote array. We could put this into an internal function
            recDagVote[recipient][recDagVoteDiff[recipient]+depth][recVotePos] = recDagVote[recipient][recDagVoteDiff[recipient]+depth][recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth]-1];
            recDagVote[recipient][recDagVoteDiff[recipient]+depth][recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth]-1]= address(0);
            recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth] -= 1;
            // remove from sentDagVote array
            sentDagVote[voter][sentDagVoteDiff[voter]+depth][i] = address(0); 

        }
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth] = 0;
    }

    // to remove a row of votes from the recDagVote array, and the corresponding votes from the sentDagVote arrays
    function removeRecDagVoteRow(address recipient, uint256 depth) internal {
        for (uint256 i = 0; i < recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth]; i++) {
            // find voter and position in sentDagVote array
            address voter = recDagVote[recipient][recDagVoteDiff[recipient]+depth][i];
            (, uint256 votePos) = findSentDagVotePosAtDepth(voter, recipient, depth);
            //remove from sentDagVote array
            // we could clean this up into an internal function
            sentDagVote[voter][sentDagVoteDiff[voter]+depth][votePos] = sentDagVote[voter][sentDagVoteDiff[voter]+depth][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth]-1];
            sentDagVote[voter][sentDagVoteDiff[voter]+depth][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth]-1]= address(0);
            sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth] -= 1;
            //remove from recDagVote array
            recDagVote[recipient][recDagVoteDiff[recipient]+depth][i] = address(0); 
        }
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth] = 0;
    }

    ///////////////// for jumping
    // to remove all rows over a certain depth from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteOverDepthInclusive(address voter, uint256 depth) internal {
        for (uint256 i = sentDagVoteDiff[voter] + depth; i < sentDagVoteDiff[voter] + MAX_REL_ROOT_DEPTH; i++) {
            removeSentDagVoteRow(voter, i);
        }
    }

    // to remove non-local votes when jumping distance and depth under the jumper.  
    function removeSentDagVoteJumpingRecursive(address voter, uint256 distance, uint256 depth) internal {
        // we only need to remove votes if we jumped out of voter's local subtree.
        // Our local subtree is at depth MAX_REL_ROOT_DEPTH - depth above the jumper. 
        // We jump out of this if the distance is larger.
        if (MAX_REL_ROOT_DEPTH - depth < distance){
            // We jumped out of our local subtree.
            // We have to remove all votes not in subtree where the jumper is the root.
            // This means votes at the jumpers depth have to be removed (so also the jumper)
            removeSentDagVoteOverDepthInclusive(voter, depth);
        }
        
        // there are DAG vote only under MAX_REL_ROOT_DEPTH. If we are there we can stop.
        if (depth == MAX_REL_ROOT_DEPTH ) {
            return;
        }

        // we repeat the procedure for our decendants
        for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
            address recipient = recTreeVote[voter][i];
            removeSentDagVoteJumpingRecursive(recipient, distance, depth+1);
        }
    }

    ///////////////// for rising
    // we remove the rows on the edges and change the frame of the dag arrays. 
    function removeDagVoteRising(address voter) internal {
        // we need to remove all votes that are not in the subtree of the voter
        removeSentDagVoteRow(voter, 1);
        sentDagVoteDiff[voter] += 1;

        removeRecDagVoteRow(voter, MAX_REL_ROOT_DEPTH-1);
        recDagVoteDiff[voter] -= 1;
    }

    // when rising a single depth up the tree,
    function removeDagVoteRisingRecursive(address voter, uint256 depth) internal {
        if (MAX_REL_ROOT_DEPTH<= depth){
            return;
        }

        removeDagVoteRising(voter);

        for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
            address recipient = recTreeVote[voter][i];
            removeDagVoteRisingRecursive(recipient, depth+1);
        }
    }

    /////////////////// for falling
    // we remove the rows on the edges and change the frame of the dag arrays.
    function removeDagVoteFalling(address voter) internal {
        // we need to remove all votes that are not in the subtree of the voter
        removeSentDagVoteRow(voter, MAX_REL_ROOT_DEPTH-1);
        sentDagVoteDiff[voter] -= 1;

        removeRecDagVoteRow(voter, 1);
        recDagVoteDiff[voter] += 1;
    }

    // when falling a single depth to one of our brothers,
    function removeDagVoteFallingRecursive(address voter, uint256 depth) internal {
        if (MAX_REL_ROOT_DEPTH<= depth){
            return;
        }
        
        removeDagVoteFalling(voter);

        for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
            address recipient = recTreeVote[voter][i];
            removeDagVoteFallingRecursive(recipient, depth+1);
        }
    }


////////////////////////////////////////
//// Local tree functions

    // to change a tree vote to recipient, who is at most maxDistance away from voter.
    function changeTreeVoteSameHeight(address voter, address recipient, uint256 maxDistance) public {
        emit SimpleEventForUpdates(0);
        (, uint256 depthDiff) = findDepthDiff(voter, recipient);
        assert (depthDiff == 1);

        (, uint256 distance) = findDistance(treeVote[voter], recipient, maxDistance);

        assert (distance <= maxDistance);

        removeSentDagVoteJumpingRecursive(voter, distance, 0);

        removeTreeVote(voter);
        addTreeVote(voter, recipient);

    }

    // equivalent to changing our tree vote to our parent's parent 
    function changeTreeVoteRise(address voter) public {
        emit SimpleEventForUpdates(0);
        address recipient = treeVote[treeVote[voter]];
        assert (recipient != address(0));
        assert (recipient != address(1));

        removeDagVoteRisingRecursive(voter, 0);

        removeTreeVote(voter);
        addTreeVote(voter, recipient);
    }

    // equivalent to changing our tree vote to our brother = parent's child
    function changeTreeVoteFall(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);
        assert (treeVote[recipient] == treeVote[voter]);
        assert (treeVote[recipient]!= address(0));
        assert (treeVote[recipient]!= address(1));


        removeDagVoteFallingRecursive(voter, 0);

        removeTreeVote(voter);
        addTreeVote(voter, recipient);
    }
}
