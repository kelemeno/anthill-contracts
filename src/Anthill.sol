// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Anthill {

    event SimpleEventForUpdates(uint32 randint);

////////////////////////////
//// State variables
    uint32 decimalPoint = 18; // total weight of each voter should be 1, but we don't have floats, so we use 10**18.  
    uint32 public MAX_REL_ROOT_DEPTH =6;
    address public root;

    mapping(address => address) public treeVote;

    mapping(address => uint32) public recTreeVoteCount;
    mapping(address => mapping(uint32 => address)) public recTreeVote;

    struct DagVote {
        address id;
        uint32 weight;
        // this is for the tables, we can find the sent-received pairs easily. 
        uint32 posInOther;
    }

    mapping(address => uint32) public sentDagVoteDiff;
    mapping(address => mapping(uint32 => uint32)) public sentDagVoteCount;
    mapping(address => mapping(uint32 => mapping(uint32 => DagVote))) public sentDagVote;
    mapping(address => uint32) public sentDagVoteTotalWeight;
    

    mapping(address => uint32) public recDagVoteDiff;
    mapping(address => mapping(uint32 => uint32)) public recDagVoteCount;
    mapping(address => mapping(uint32 => mapping(uint32 => DagVote))) public recDagVote;

    mapping(address => uint256) public reputation;
    mapping(address => string) public names;
    

////////////////////////////////////////
/////// Variable readers 

    function readRoot() public view returns(address){
        return root;
    }

    function readMaxRelRootDepth() public view returns(uint32){
        return MAX_REL_ROOT_DEPTH;
    }

    function readReputation(address voter) public view returns(uint256){
        return reputation[voter];
    }

    function readName(address voter) public view returns(string memory){
        return names[voter];
    }

    function readSentTreeVote(address voter) public view returns(address){
        return treeVote[voter];
    }

    function readRecTreeVoteCount(address recipient) public view returns(uint32){
            return recTreeVoteCount[recipient];
    }

    function readRecTreeVote(address recipient, uint32 votePos) public view returns(address){
            return recTreeVote[recipient][votePos];
    }

    function readSentDagVoteDiff(address voter) public view returns(uint32){
            return sentDagVoteDiff[voter];
    }

    function readSentDagVoteCount(address voter, uint32 heightDiff) public view returns(uint32){
            return sentDagVoteCount[voter][sentDagVoteDiff[voter]+heightDiff];
    }

    function readSentDagVote(address voter, uint32 heightDiff, uint32 votePos) public view returns( DagVote memory){
            return sentDagVote[voter][sentDagVoteDiff[voter]+heightDiff][votePos];
    }

    function readSentDagVoteTotalWeight(address voter) public view returns( uint32){
            return sentDagVoteTotalWeight[voter];
    }

    function readRecDagVoteDiff(address voter) public view returns(uint32){
            return recDagVoteDiff[voter];
    }

    function readRecDagVoteCount(address voter, uint32 heightDiff) public view returns(uint32){
            return recDagVoteCount[voter][sentDagVoteDiff[voter]+heightDiff];
    }

    function readRecDagVote(address voter, uint32 heightDiff, uint32 votePos) public view returns(DagVote memory){
            return recDagVote[voter][sentDagVoteDiff[voter]+heightDiff][votePos];
    }

////////////////////////////////////////
//// Neighbour tree externals


    // when we first join the tree
    function joinTree(address voter, string calldata name, address recipient) public {
        emit SimpleEventForUpdates(0);

        assert (treeVote[voter] == address(0));

        assert (treeVote[recipient] != address(0));
        treeVote[voter] = recipient;

        names[voter] = name;
        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;
    }

    // when we first join the tree without a parent
    function joinTreeAsRoot(address voter) public {
        emit SimpleEventForUpdates(1);
        
        assert (treeVote[voter] == address(0));
        // assert (root == address(0));
        treeVote[voter] = address(1);
        if (root == address(0)) {
            root = voter;
        }
    }

////////////////////////////////////////
//// Neighbour tree finder/internals    
    function findRecTreeVotePos(address voter, address recipient) public view returns (bool voted, uint32 votePos) {
        for (uint32 i = 0; i < recTreeVoteCount[recipient]; i++) {
            if (recTreeVote[recipient][i] == voter) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    //// we should add public version of this
    function removeTreeVote(address voter) internal {
        address recipient = treeVote[voter];
        (, uint32 votePos) = findRecTreeVotePos(voter, recipient);

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
    function findRelRoot(address voter) public view returns (address relRoot, uint32 relRootDiff){
        assert (treeVote[voter] != address(0));

        relRoot = voter;
        address parent;
        uint32 relRootDiff;

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
    function findDepthDiff(address voter, address recipient) public view returns (bool isLocal, uint32 depthDiff){
        
        if ((treeVote[voter] == address(0)) || (treeVote[recipient] == address(0))) {
            return (false, 0);
        }

        (address relRoot, uint32 relRootDiff) = findRelRoot(voter);
        address recipientAncestor = recipient;

        for (uint32 i = 0; i < relRootDiff; i++) {
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
    function findDistance(address add1, address add2, uint32 maxDistance) public view returns (bool isLocal, uint32 distance) {
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
    function findSentDagVotePosAtDepth(address voter, address recipient, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        
        uint32  diff = sentDagVoteDiff[voter];

        for (uint32 i = 0; i < sentDagVoteCount[voter][diff+depth] ; i++) {

            if (sentDagVote[voter][diff+depth][i].id == recipient) {
                return (true, i, sentDagVote[voter][diff+depth][i]);
            }
        }

        return (false, 0, DagVote(address(0), 0, 0));

    }

    // to check the existence and to find the position of a vote in a given row of the recDagVote array
    function findRecDagVotePosAtDepth(address voter, address recipient, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        
        uint32 count = readRecDagVoteCount(recipient, depth);

        for (uint32 i = 0; i < count ; i++) {
            if (readRecDagVote(recipient, depth, i).id == voter) {
                return (true, i, readRecDagVote(recipient, depth, i));
            }
        }
        
        return (false, 0, DagVote(address(0), 0, 0));
    }

    function findLastSentDagVoteAtDepth(address voter, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        
        uint32 count = readSentDagVoteCount(voter, depth);

        if (count == 0) {
            return (false, 0, DagVote(address(0), 0, 0));
        }

        return (true, count-1, readSentDagVote(voter, depth, count-1));
    }

    function findLastRecDagVoteAtDepth(address recipient, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
       
        uint32 count = readRecDagVoteCount(recipient, depth);

        if (count == 0) {
            return (false, 0, DagVote(address(0), 0, 0));
        }

        return (true, count-1, readRecDagVote(recipient, depth, count-1));
    }

    // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
    function findSentDagVote(address voter, address recipient) public view returns (bool voted, uint32 depthDiff, uint32 votePos, DagVote memory dagVote){ 
        (bool votable, uint32 depthDiff) = findDepthDiff(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0,  DagVote(address(0), 0, 0));
        }

        (voted,  votePos, dagVote) = findSentDagVotePosAtDepth(voter, recipient, depthDiff);

        return (voted, depthDiff, votePos, dagVote);
    }

    // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
    function findRecDagVote(address voter, address recipient) public view returns (bool voted, uint32 depthDiff, uint32 votePos, DagVote memory dagVote){
        (bool votable, uint32 depthDiff) = findDepthDiff(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0,  DagVote(address(0), 0, 0));
        }

        (voted, votePos, dagVote) = findRecDagVotePosAtDepth(voter, recipient, depthDiff);

        return (voted, depthDiff, votePos, dagVote);
    }


////////////////////////////////////////////////////////////////////////
//// Dag externals
    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    // currently this is the only function that adds Dag votes, so there is no need to break it apart
    function addDagVote(address voter, address recipient, uint32 weight) public {
        emit SimpleEventForUpdates(0);

        (bool voted, uint32 depthDiff, , ) = findSentDagVote(voter, recipient);
        assert (voted == false);

        // add DagVotes. 
        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]] = DagVote({id: recipient, weight: weight, posInOther: recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff]});
        recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff]] = DagVote({id: voter, weight: weight, posInOther: sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]});

        // increase DagVoteCount
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] += 1;
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff] += 1;  

        //increase sentDagVoteWeights
        sentDagVoteTotalWeight[voter] += weight;
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);
        
        // find the votes we delete
        (bool voted, uint32 depthDiff, uint32 sentVotePos , DagVote memory sDagVote) = findSentDagVote(voter, recipient);
        assert (voted == true);

        uint32 recVotePos = sDagVote.posInOther;

        // move the last vote to the position of the vote we delete. This overwrites the original vote we delete
            // copying
        (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDepth(voter, depthDiff);
        (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDepth(recipient, depthDiff);

            //moving
        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentVotePos] =  copiedSentDagVote;
        recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recVotePos] =  copiedRecDagVote;

        // change posInOther of the moved votes 
        changePositionOnOtherOfSent(depthDiff, copiedSentDagVote, sentVotePos);
        changePositionOnOtherOfRec(depthDiff, copiedRecDagVote, recVotePos); 

        // delete the copied hence duplicate votes
        deleteLastSentDagVoteAtDepth(voter, depthDiff);
        deleteLastRecDagVoteAtDepth(recipient, depthDiff);

        //change votecounts
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] -= 1;
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff] -= 1;

        // change sentDagVoteWeights. 
        // this is singular, as we only track the weight of the voter, and not the recipient
        sentDagVoteTotalWeight[voter] -= sDagVote.weight;
    }

     
////////////////////////////////////////////////////////////////////////
//// Dag internals
    //////// changing positions 

     function changePositionOnOtherOfSent(uint32 depthDiff, DagVote memory movedVote, uint32 newPos) internal{
        recDagVote[movedVote.id][recDagVoteDiff[movedVote.id]+depthDiff][movedVote.posInOther].posInOther = newPos;
    }

    function changePositionOnOtherOfRec(uint32 depthDiff, DagVote memory movedVote, uint32 newPos) internal {
        sentDagVote[movedVote.id][recDagVoteDiff[movedVote.id]+depthDiff][movedVote.posInOther].posInOther = newPos;

    }

    /////////// delete and removal functions
    function deleteLastSentDagVoteAtDepth(address voter, uint32 depthDiff) internal {
        delete sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]-1];
    }

    function deleteLastRecDagVoteAtDepth(address recipient, uint32 depthDiff) internal {
        delete recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff]-1];
    }   

     // here we dont care about copying the sent votes, as they will be removed in the row removal. 
     // this is nearly the same as removeDagVote, but we do the operations only for the rec votes. 
     // to grok this, grok removeDagVote
    function removeSentDagVoteAtDepthPosForRowRemoval(address voter, uint32 depthDiff, uint32 sentVotePos) internal {

        // find the vote we delete
        DagVote memory sDagVote = readSentDagVote(voter, depthDiff, sentVotePos);
        uint32 recVotePos = sDagVote.posInOther;
        address recipient = sDagVote.id;

        // move the last vote to the position of the vote we delete. This overwrites the original vote we delete
            //copying
        // (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDepth(voter, depthDiff);
        (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDepth(recipient, depthDiff);

            //moving
        // sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentVotePos] =  copiedSentDagVote;
            delete sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentVotePos]; //this is an extra row, we did not write it over, so we delete it
        recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recVotePos] =  copiedRecDagVote;

        // change posInOther of the moved votes 
        // movePositionOnOtherOfSent(depthDiff, copiedSentDagVote, sentVotePos);
        changePositionOnOtherOfRec(depthDiff, copiedRecDagVote, recVotePos); 

        // delete the copied hence duplicate votes
        // deleteLastSentDagVoteAtDepth(voter, depthDiff);
        deleteLastRecDagVoteAtDepth(recipient, depthDiff);

        //change votecounts
        // sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] -= 1;
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff] -= 1;

        // change sentDagVoteWeights
        // we don't comment this out, as we don't track the total weight for each row, but for the whole table. 
        sentDagVoteTotalWeight[voter] -= sDagVote.weight;

    } 

    // here we dont care about copying the sent votes, as they will be removed in the row removal. 
     // this is nearly the same as removeDagVote, but we do the operations only for the rec votes. 
     // to grok this grok removeDagVote
    function removeRecDagVoteAtDepthPosForRowRemoval(address recipient, uint32 depthDiff, uint32 sentVotePos) internal {

        // find the vote we delete
        DagVote memory rDagVote = readRecDagVote(recipient, depthDiff, sentVotePos);
        uint32 recVotePos = rDagVote.posInOther;
        address voter = rDagVote.id;

        // move the last vote to the position of the vote we delete. This overwrites the original vote we delete
            //copying
        (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDepth(voter, depthDiff);
        // (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDepth(recipient, depthDiff);

            //moving
        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentVotePos] =  copiedSentDagVote;
        // recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recVotePos] =  copiedRecDagVote;  
            delete recDagVote[recipient][recDagVoteDiff[recipient]+depthDiff][recVotePos]; //this is an extra row, we did not write it over, so we delete it

        // change posInOther of the moved votes 
        changePositionOnOtherOfSent(depthDiff, copiedSentDagVote, sentVotePos);
        // movePositionOnOtherOfRec(depthDiff, copiedRecDagVote, recVotePos); 

        // delete the copied hence duplicate votes
        deleteLastSentDagVoteAtDepth(voter, depthDiff);
        // deleteLastRecDagVoteAtDepth(recipient, depthDiff);

        //change votecounts
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] -= 1;
        // recDagVoteCount[recipient][recDagVoteDiff[recipient]+depthDiff] -= 1;

        // change sentDagVoteWeights
        sentDagVoteTotalWeight[voter] -= rDagVote.weight;

    } 
    ///////////////////// Row removal functions 

    // to remove a row of votes from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteRow(address voter, uint32 depth) internal {
        for (uint32 i = 0; i < readSentDagVoteCount(voter, depth); i++) {
            removeSentDagVoteAtDepthPosForRowRemoval(voter, depth, i);
        }
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth] = 0;
    }

    // to remove a row of votes from the recDagVote array, and the corresponding votes from the sentDagVote arrays
    function removeRecDagVoteRow(address recipient, uint32 depth) internal {
        for (uint32 i = 0; i < readRecDagVoteCount(recipient, depth); i++) {
            removeRecDagVoteAtDepthPosForRowRemoval(recipient, depth, i);
        }
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth] = 0;
    }
    
    ///////////////////////////////////////////// For local tree modifications
    ///////////////// for jumping
    // to remove all rows over a certain depth from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteOverDepthInclusive(address voter, uint32 depth) internal {
        for (uint32 i = sentDagVoteDiff[voter] + depth; i < sentDagVoteDiff[voter] + MAX_REL_ROOT_DEPTH; i++) {
            removeSentDagVoteRow(voter, i);
        }
    }

    // to remove non-local votes when jumping distance and depth under the jumper.  
    function removeSentDagVoteJumpingRecursive(address voter, uint32 distance, uint32 depth) internal {
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
        for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
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
    function removeDagVoteRisingRecursive(address voter, uint32 depth) internal {
        if (MAX_REL_ROOT_DEPTH<= depth){
            return;
        }

        removeDagVoteRising(voter);

        for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
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
    function removeDagVoteFallingRecursive(address voter, uint32 depth) internal {
        if (MAX_REL_ROOT_DEPTH<= depth){
            return;
        }
        
        removeDagVoteFalling(voter);

        for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
            address recipient = recTreeVote[voter][i];
            removeDagVoteFallingRecursive(recipient, depth+1);
        }
    }


////////////////////////////////////////
//// Local tree functions

    // to change a tree vote to recipient, who is at most maxDistance away from voter.
    function changeTreeVoteSameHeight(address voter, address recipient, uint32 maxDistance) public {
        emit SimpleEventForUpdates(0);
        (, uint32 depthDiff) = findDepthDiff(voter, recipient);
        assert (depthDiff == 1);

        (, uint32 distance) = findDistance(treeVote[voter], recipient, maxDistance);

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

////////////////////////////////////////////////////////
///// Global functions, i.e. calculate reputation. Later min height, and restrictions for calculating reputation can come here.  
    
        // to calculate the reputation of a voter, i.e. the sum of the votes of the voter and all its descendants
    function calculateReputation(address voter) public returns (uint256){
        uint256 voterReputation = 0 ;
            
        for (uint32 i=0; i< MAX_REL_ROOT_DEPTH; i++){
            for (uint32 j =0; j< readRecDagVoteCount(voter, i); j++) {
            DagVote memory rDagVote = readRecDagVote(voter, i, j);
                voterReputation += calculateReputation(rDagVote.id)*(rDagVote.weight)/ sentDagVoteTotalWeight[rDagVote.id];
            }
        }
        // for the voter themselves
        voterReputation += 10**decimalPoint;
        reputation[voter] = voterReputation;
        return voterReputation;
        }
    
       
}
