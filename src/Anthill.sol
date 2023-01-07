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

    mapping(address => uint32) public sentDagVoteDistDiff;
    mapping(address => uint32) public sentDagVoteDepthDiff;
    mapping(address => mapping(uint32 => mapping(uint32 => uint32))) public sentDagVoteCount; // voter -> distance -> heightDiff -> count
    mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote)))) public sentDagVote; // voter -> distance -> heightDiff -> counter -> DagVote
    
    mapping(address => uint32) public sentDagVoteTotalWeight;
    

    mapping(address => uint32) public recDagVoteDistDiff;
    mapping(address => uint32) public recDagVoteDepthDiff;
    mapping(address => mapping(uint32 => mapping(uint32 => uint32))) public recDagVoteCount; // voter -> distance -> heightDiff -> count
    mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote)))) public recDagVote; // voter -> distance -> heightDiff -> counter -> DagVote

    mapping(address => uint256) public reputation;
    mapping(address => string) public names;
    

////////////////////////////////////////
/////// Variable readers 
    // root/base 
    function readRoot() public view returns(address){
        return root;
    }

    function readMaxRelRootDepth() public view returns(uint32){
        return MAX_REL_ROOT_DEPTH;
    }

    // for node properties
    function readReputation(address voter) public view returns(uint256){
        return reputation[voter];
    }

    function readName(address voter) public view returns(string memory){
        return names[voter];
    }

    // for tree votes
    function readSentTreeVote(address voter) public view returns(address){
        return treeVote[voter];
    }

    function readRecTreeVoteCount(address recipient) public view returns(uint32){
            return recTreeVoteCount[recipient];
    }

    function readRecTreeVote(address recipient, uint32 votePos) public view returns(address){
            return recTreeVote[recipient][votePos];
    }

    // for sent dag 
    
    function readSentDagVoteDistDiff(address voter) external view returns(uint32){
            return sentDagVoteDistDiff[voter];
    }

    function readSentDagVoteDepthDiff(address voter) external view returns(uint32){
            return sentDagVoteDepthDiff[voter];
    }

    function readSentDagVoteCount(address voter, uint32 dist, uint32 height) public view returns(uint32){
            return sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+height];
    }

    function readSentDagVote(address voter, uint32 dist, uint32 height, uint32 votePos) public view returns( DagVote memory){
            return sentDagVote[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+height][votePos];
    }

    
    function readSentDagVoteTotalWeight(address voter) public view returns( uint32){
            return sentDagVoteTotalWeight[voter];
    }
    // for rec Dag votes

    function readRecDagVoteDistDiff(address voter) external view returns(uint32){
            return sentDagVoteDistDiff[voter];
    }

    function readRecDagVoteDepthDiff(address voter) external view returns(uint32){
            return sentDagVoteDepthDiff[voter];
    }


    function readRecDagVoteCount(address voter, uint32 dist, uint32 height) public view returns(uint32){
            return recDagVoteCount[voter][recDagVoteDistDiff[voter]+dist][recDagVoteDepthDiff[voter]+height];
    }

    function readRecDagVote(address voter, uint32 dist, uint32 height, uint32 votePos) public view returns(DagVote memory){
            return recDagVote[voter][recDagVoteDistDiff[voter]+dist][recDagVoteDepthDiff[voter]+height][votePos];
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
    function joinTreeAsRoot(address voter, string calldata name) public {
        emit SimpleEventForUpdates(1);
        
        assert (treeVote[voter] == address(0));
        assert (root == address(0));

        names[voter] = name;
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

    function findNthParent(address voter, uint32 height) public view returns (address parent){
        if (height == 0) {
            return voter;
        }

        assert (treeVote[voter] != address(0));

        if (treeVote[voter] == address(1)) {
            return voter;
        }

        return findNthParent(treeVote[voter], height-1);
    }

    // to find our relative root, our ancestor at depth MAX_REL_ROOT_DEPTH
    function findRelRoot(address voter) public view returns (address relRoot, uint32 relDepth){
        assert (treeVote[voter] != address(0));

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
    function findRelDepth(address voter, address recipient) public view returns (bool isLocal, uint32 relDepth){
        
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

    // to find the distance between voter and recipient, within maxDistance. Nodes do not have to be locally close
    function findDistAtSameDepth(address add1, address add2, uint32 maxDistance) public view returns (bool isLocal, uint32 distance) {
        if ( treeVote[add1] == address(0) || treeVote[add2] == address(0)) {
            return (false, 0);
        }

        if (add1 == add2){
            return (true, 0);
        }

        if (treeVote[add1] == address(1) || treeVote[add2] == address(1)) {
            return (false, 0);
        }

        if (maxDistance == 0) {
            return (false, 0);
        }

        (isLocal, distance) = findDistAtSameDepth(treeVote[add1], treeVote[add2], maxDistance -1);

        // we could remove this check and return isLocal, distance + 1
        if (isLocal == true) {
            return (true, distance + 1);
        }

        return (false, 0);
    }

    // 
    function findDistDepth(address voter, address recipient) public view returns (bool isLocal, uint32 distance, uint32 relDepth){
        if (treeVote[voter] == address(0) || treeVote[recipient] == address(0)) {
            return (false, 0, 0);
        }

        ( isLocal,  relDepth) = findRelDepth(voter, recipient);
        address voterAnscenstor = findNthParent(voter, relDepth);

        (,  distance)= findDistAtSameDepth(voterAnscenstor, recipient, MAX_REL_ROOT_DEPTH-relDepth);

        return (isLocal, distance+relDepth, relDepth);
    }

    

////////////////////////////////////////////////////////////////////////
//// DAG finders
    // to check the existence and to find the position of a vote in a given row of the sentDagVote array
    function findSentDagVotePosAtDistDepth(address voter, address recipient, uint32 dist,  uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        for (uint32 i = 0; i < readSentDagVoteCount(voter, dist, depth) ; i++) {
            DagVote memory sDagVote = readSentDagVote(voter, dist, depth, i);
            if (sDagVote.id == recipient) {
                return (true, i, sDagVote);
            }
        }

        return (false, 0, DagVote(address(0), 0, 0));
    }

    // to check the existence and to find the position of a vote in a given row of the recDagVote array
    function findRecDagVotePosAtDistDepth(address voter, address recipient, uint32 dist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        for (uint32 i = 0; i < readRecDagVoteCount(recipient, dist, depth) ; i++) {
            DagVote memory rDagVote = readRecDagVote(recipient, dist, depth, i);
            if (rDagVote.id == voter) {
                return (true, i, rDagVote);
            }
        }

        return (false, 0, DagVote(address(0), 0, 0));
    }

    function findLastSentDagVoteAtDistDepth(address voter, uint32 dist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        
        uint32 count = readSentDagVoteCount(voter, dist, depth);

        if (count == 0) {
            return (false, 0, DagVote(address(0), 0, 0));
        }

        return (true, count-1, readSentDagVote(voter, dist ,depth, count-1));
    }

    function findLastRecDagVoteAtDistDepth(address recipient, uint32 dist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
       
        uint32 count = readRecDagVoteCount(recipient, dist, depth);

        if (count == 0) {
            return (false, 0, DagVote(address(0), 0, 0));
        }

        return (true, count-1, readRecDagVote(recipient,dist,  depth, count-1));
    }

    // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
    function findSentDagVote(address voter, address recipient) public view returns (bool voted, uint32 dist,  uint32 depth, uint32 votePos, DagVote memory dagVote){ 
        bool votable;
        (votable,  dist,  depth) = findDistDepth(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0, 0,  DagVote(address(0), 0, 0));
        }

        (voted,  votePos, dagVote) = findSentDagVotePosAtDistDepth(voter, recipient, dist, depth);

        return (voted, dist, depth, votePos, dagVote);
    }

    // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
    function findRecDagVote(address voter, address recipient) public view returns (bool voted, uint32 dist, uint32 depth, uint32 votePos, DagVote memory dagVote){
        bool votable;
        ( votable, dist, depth) = findDistDepth(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0, 0,  DagVote(address(0), 0, 0));
        }

        (voted, votePos, dagVote) = findRecDagVotePosAtDistDepth(voter, recipient, dist, depth);

        return (voted, dist,  depth, votePos, dagVote);
    }


////////////////////////////////////////////////////////////////////////
//// Dag externals
    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    function addDagVote(address voter, address recipient, uint32 weight) public {
        emit SimpleEventForUpdates(0);

        (bool voted, uint32 dist, uint32 depth, , ) = findSentDagVote(voter, recipient);
        assert (voted == false);

        // add DagVotes. 
        DagVote memory sDagVote =  DagVote({id: recipient, weight: weight, posInOther: readRecDagVoteCount(recipient, dist, depth)});
        sentDagAppend(voter, dist, depth, sDagVote);

        DagVote memory rDagVote =  DagVote({id: voter, weight: weight, posInOther: readSentDagVoteCount(voter, dist, depth)});
        recDagAppend(recipient, dist, depth, rDagVote);
        

       

        //increase sentDagVoteWeights
        sentDagVoteTotalWeight[voter] += weight;
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);
        
        // find the votes we delete
        (bool voted, uint32 dist, uint32 depth, uint32 sentVotePos, DagVote memory sDagVote) = findSentDagVote(voter, recipient);
        assert (voted == true);

        uint32 recVotePos = sDagVote.posInOther;

        // move the last vote to the position of the vote we delete. This overwrites the original vote we delete
            // copying
        (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDistDepth(voter, dist, depth);
        (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDistDepth(recipient, dist, depth);

            //moving
        sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][sentVotePos] =  copiedSentDagVote;
        recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][recVotePos] =  copiedRecDagVote;

        // change posInOther of the moved votes 
        changePositionOnOtherOfSent(dist, depth, copiedSentDagVote, sentVotePos);
        changePositionOnOtherOfRec(dist, depth, copiedRecDagVote, recVotePos); 

        // delete the copied hence duplicate votes
        deleteLastSentDagVoteAtDistDepth( voter, dist,  depth);
        deleteLastRecDagVoteAtDistDepth(recipient, dist, depth);

        //change votecounts
        sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth] -= 1;
        recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth] -= 1;

        // change sentDagVoteWeights. 
        // this is singular, as we only track the weight of the voter, and not the recipient
        sentDagVoteTotalWeight[voter] -= sDagVote.weight;
    }

     
////////////////////////////////////////////////////////////////////////
//// Dag internals

    // appending votes 
    function sentDagAppend(address voter, uint32 dist, uint32 depth, DagVote memory dagVote ) internal{
        sentDagVote[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+ depth][readSentDagVoteCount(voter, dist , depth)] = dagVote; 
        sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+depth] += 1;
    }

    function recDagAppend(address recipient, uint32 dist, uint32 depth, DagVote memory dagVote ) internal{
        recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][readRecDagVoteCount(recipient, dist, depth)] = dagVote; 
        recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth] += 1;  

    }

    //////// changing positions 

    function changePositionOnOtherOfSent(uint32 dist, uint32 depth, DagVote memory movedVote, uint32 newPos) internal{
        recDagVote[movedVote.id][recDagVoteDistDiff[movedVote.id]+ dist][recDagVoteDepthDiff[movedVote.id]+depth][movedVote.posInOther].posInOther = newPos;
    }

    function changePositionOnOtherOfRec(uint32 dist,  uint32 depth, DagVote memory movedVote, uint32 newPos) internal {
        sentDagVote[movedVote.id][sentDagVoteDistDiff[movedVote.id]+ dist][sentDagVoteDepthDiff[movedVote.id]+depth][movedVote.posInOther].posInOther = newPos;
    }

    /////////// delete and removal functions

    function deleteLastSentDagVoteAtDistDepth(address voter, uint32 dist, uint32 depth) internal {
        delete sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][readSentDagVoteCount(voter, dist, depth-1)];
    }

    function deleteLastRecDagVoteAtDistDepth(address recipient, uint32 dist, uint32 depth) internal {
        delete recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][readRecDagVoteCount(recipient, dist, depth-1)];
    }   

     // here we dont care about copying the sent votes, as they will be removed in the row removal. 
     // this is nearly the same as removeDagVote, but we do the operations only for the rec votes. 
     // to grok this, grok removeDagVote
    function removeSentDagVoteAtDistDepthPosForCellRemoval(address voter, uint32 dist,  uint32 depth, uint32 sentVotePos) internal {

        // find the vote we delete
        DagVote memory sDagVote = readSentDagVote(voter,dist, depth, sentVotePos);
        uint32 recVotePos = sDagVote.posInOther;
        address recipient = sDagVote.id;

        // move the last vote to the position of the vote we delete. This overwrites the original vote we delete
            //copying
        // (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDepth(voter,dist,  depth);
        (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDistDepth(recipient,dist,  depth);

            //moving
        // sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][sentVotePos] =  copiedSentDagVote;
        delete sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][sentVotePos]; //this is an extra row, we did not write it over, so we delete it
        recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][recVotePos] =  copiedRecDagVote;

        // change posInOther of the moved votes 
        // movePositionOnOtherOfSent(depth, copiedSentDagVote, sentVotePos);
        changePositionOnOtherOfRec(dist, depth, copiedRecDagVote, recVotePos); 

        // delete the copied hence duplicate votes
        // deleteLastSentDagVoteAtDepth(voter, dist, depth);
        deleteLastRecDagVoteAtDistDepth(recipient, dist, depth);

        //change votecounts
        // sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth] -= 1;
        recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth] -= 1;

        // change sentDagVoteWeights
        // we don't comment this out, as we don't track the total weight for each row, but for the whole table. 
        sentDagVoteTotalWeight[voter] -= sDagVote.weight;

    } 

    // here we dont care about copying the sent votes, as they will be removed in the row removal. 
     // this is nearly the same as removeDagVote, but we do the operations only for the rec votes. 
     // to grok this grok removeDagVote
    function removeRecDagVoteAtDepthPosForCellRemoval(address recipient, uint32 dist, uint32 depth, uint32 sentVotePos) internal {

        // find the vote we delete
        DagVote memory rDagVote = readRecDagVote(recipient, dist, depth, sentVotePos);
        uint32 recVotePos = rDagVote.posInOther;
        address voter = rDagVote.id;

        // move the last vote to the position of the vote we delete. This overwrites the original vote we delete
            //copying
        (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDistDepth(voter, dist, depth);
        // (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDepth(recipient, dist, depth);

            //moving
        sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][sentVotePos] =  copiedSentDagVote;
        // recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][recVotePos] =  copiedRecDagVote;  
            delete recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][recVotePos]; //this is an extra row, we did not write it over, so we delete it

        // change posInOther of the moved votes 
        changePositionOnOtherOfSent(dist, depth, copiedSentDagVote, sentVotePos);
        // movePositionOnOtherOfRec(dist, depth, copiedRecDagVote, recVotePos); 

        // delete the copied hence duplicate votes
        deleteLastSentDagVoteAtDistDepth(voter, dist, depth);
        // deleteLastRecDagVoteAtDepth(recipient, dist, depth);

        //change votecounts
        sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth] -= 1;
        // recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth] -= 1;

        // change sentDagVoteWeights
        sentDagVoteTotalWeight[voter] -= rDagVote.weight;

    } 
    ///////////////////// Cell removal functions 

    // to remove a row of votes from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteCell(address voter, uint32 dist, uint32 depth) internal {
        for (uint32 i = 0; i < readSentDagVoteCount(voter, dist, depth); i++) {
            removeSentDagVoteAtDistDepthPosForCellRemoval(voter, dist, depth, i);
        }
        sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth] = 0;
    }

    // to remove a row of votes from the recDagVote array, and the corresponding votes from the sentDagVote arrays
    function removeRecDagVoteCell(address recipient, uint32 dist, uint32 depth) internal {
        for (uint32 i = 0; i < readRecDagVoteCount(recipient, dist, depth); i++) {
            removeRecDagVoteAtDepthPosForCellRemoval(recipient, dist, depth, i);
        }
        recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth] = 0;
    }
    
    ///////////////////////////////////////
    ///////////////// Line removal functions

    function removeSentDagVoteLineDistEqualsDepthPlusValue(address voter, uint32 value) internal {
        for (uint32 i = value+1; i <= MAX_REL_ROOT_DEPTH; i++) {
            removeSentDagVoteCell(voter, i, i-value);
        }
    }

    function removeRecDagVoteLineDistEqualsDepthPlusValue(address voter, uint32 value) internal {
        for (uint32 i = value+1; i <= MAX_REL_ROOT_DEPTH; i++) {
            removeRecDagVoteCell(voter, i, i-value);
        }
    }

    function removeSentDagVoteLineDepthEqualsValue(address voter, uint32 value) internal {
        for (uint32 i = value; i <= MAX_REL_ROOT_DEPTH ; i++) {
            removeSentDagVoteCell(voter, i, value);
        }
    }

    function removeRecDagVoteLineDepthEqualsValue(address voter, uint32 value) internal {
        for (uint32 i = value; i <= MAX_REL_ROOT_DEPTH; i++) {
            removeSentDagVoteCell(voter, i, value);
        }
    }

    function removeSentDagVoteLineDistEqualsValue(address voter, uint32 value) internal {
        for (uint32 i = 1; i <= value ; i++) {
            removeSentDagVoteCell(voter, value, i);
        }
    }

    function removeRecDagVoteLineDistEqualsValue(address voter, uint32 value) internal {
        for (uint32 i = 1; i <= value; i++) {
            removeSentDagVoteCell(voter, value, i);
        }
    }


    ///////////////////////////////////////////// For local tree modifications
    ///////////////// for jumping
    // to remove all rows over a certain depth from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteOverDistance(address voter, uint32 dist) internal {
        for (uint32 i = sentDagVoteDepthDiff[voter] + dist; i < sentDagVoteDepthDiff[voter] + MAX_REL_ROOT_DEPTH; i++) {
            removeSentDagVoteLineDistEqualsValue(voter, i);
        }
    }

    // to remove non-local votes when jumping distance and depth under the jumper.  
    // currently not used, so internal 
    function removeSentDagVoteCommonJumpingRecursive(address voter, uint32 jumpDistance, uint32 depth) internal {
        // voter is not the jumper but its descendant, distance is the dist of the jump, and depth is how deep we are in the recursion, going down the tree.

        // we only need to remove votes if we jumped out of voter's local subtree.
        // if we are the jumpers, and jump out of our local subtree, we have to remove all our sent votes.
        // this would apply for the voter as well, except they keep the votes that are descendants of the jumper. 
 

        // The voters local subtree is at depth MAX_REL_ROOT_DEPTH - depth above the jumper. 
        // We jump out of this if the distance is larger.
        if (MAX_REL_ROOT_DEPTH - depth < jumpDistance){
            // We jumped out of our local subtree.
            // We remove all votes not under the jumper.
            removeSentDagVoteOverDistance(voter, depth);
        }
        
        // there are DAG vote only under MAX_REL_ROOT_DEPTH. If we are there we can stop.
        if (depth == MAX_REL_ROOT_DEPTH ) {
            return;
        }

        // we repeat the procedure for our decendants
        for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
            address recipient = recTreeVote[voter][i];
            removeSentDagVoteCommonJumpingRecursive(recipient, jumpDistance, depth+1);
        }
    }

    ///////////////// for rising
    // we remove the rows on the edges and change the frame of the dag arrays. 
    function removeDagVoteRising(address voter) internal {
        // we need to remove all votes that are not in the subtree of the voter

        // sent trianlge moves down
        removeSentDagVoteLineDepthEqualsValue(voter,  1);
        sentDagVoteDepthDiff[voter] += 1;

        // rec triangle moves up
        removeRecDagVoteLineDistEqualsDepthPlusValue(voter, 0);
        recDagVoteDepthDiff[voter] -= 1;
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

        // sent trianlge moves up
        removeSentDagVoteLineDistEqualsDepthPlusValue(voter, 0);
        sentDagVoteDepthDiff[voter] -= 1;

        // rec triangle moves down
        removeRecDagVoteLineDepthEqualsValue(voter, 1);
        recDagVoteDepthDiff[voter] += 1;
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
    function changeTreeVoteSameHeight(address voter, address recipient, uint32 maxDistance) internal {
        emit SimpleEventForUpdates(0);
        (, uint32 depth) = findRelDepth(voter, recipient);
        assert (depth == 1);

        (, uint32 distance) = findDistAtSameDepth(treeVote[voter], recipient, maxDistance);

        assert (distance <= maxDistance);

        removeSentDagVoteCommonJumpingRecursive(voter, distance, 0);

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
    function calculateReputation(address voter)  internal returns (uint256){
        uint256 voterReputation = 0 ;

        for (uint32 dist=0; dist< MAX_REL_ROOT_DEPTH; dist++){    
            for (uint32 depth=0; depth< MAX_REL_ROOT_DEPTH; depth++){
                for (uint32 count =0; depth< readRecDagVoteCount(voter, dist, depth); depth++) {
                DagVote memory rDagVote = readRecDagVote(voter, dist, depth, count);
                    voterReputation += calculateReputation(rDagVote.id)*(rDagVote.weight)/ sentDagVoteTotalWeight[rDagVote.id];
                }
            }
        }
        // for the voter themselves
        voterReputation += 10**decimalPoint;
        reputation[voter] = voterReputation;
        return voterReputation;
    }
    
    
    function switchPositionWithParent(address voter) public {
        emit SimpleEventForUpdates(0);
        address parent = treeVote[voter];
        assert (parent != address(0));
        assert (parent != address(1));
        
        uint256 voterRep = calculateReputation(voter);
        uint256 parentRep = calculateReputation(parent);

        if (voterRep > parentRep){
            removeDagVoteFalling(parent);
            removeDagVoteRising(voter);
        }
        treeVote[voter] = treeVote[parent];
        treeVote[parent] = voter;
    }
}
