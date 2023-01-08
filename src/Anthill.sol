// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Anthill {

    event SimpleEventForUpdates(uint32 randint);

////////////////////////////
//// State variables
    uint32 decimalPoint = 18; // total weight of each voter should be 1, but we don't have floats, so we use 10**18.  
    uint32 public MAX_REL_ROOT_DEPTH =6;
    address public root;

    mapping(address => string) public names;
    mapping(address => address) public treeVote;

    mapping(address => uint32) public recTreeVoteCount;
    mapping(address => mapping(uint32 => address)) public recTreeVote;

    struct DagVote {
        address id;
        uint32 weight;
        // this is for the tables, we can find the sent-received pairs easily. 
        uint32 posInOther;
    }

    mapping(address => uint32) public sentDagVoteDistDiff; // voter -> dist -> depthdiff
    mapping(address => uint32) public sentDagVoteDepthDiff;
    mapping(address => mapping(uint32 => mapping(uint32 => uint32))) public sentDagVoteCount; // voter -> distance -> height -> count
    mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote)))) public sentDagVote; // voter -> distance -> heightDiff -> counter -> DagVote
    
    mapping(address => uint32) public sentDagVoteTotalWeight;
    

    mapping(address => uint32) public recDagVoteDistDiff;
    mapping(address => uint32) public recDagVoteDepthDiff;
    mapping(address => mapping(uint32 => mapping(uint32 => uint32))) public recDagVoteCount; // voter -> distance -> heightDiff -> count
    mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote)))) public recDagVote; // voter -> distance -> heightDiff -> counter -> DagVote

    mapping(address => uint256) public reputation;
   
    

//////////////////////////////////////////////////////////////////////////////////////////////////////////
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

    function readSentDagVoteDepthDiff(address voter, uint32 dist) external view returns(uint32){
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

    function readRecDagVoteDistDiff(address recipient) external view returns(uint32){
            return recDagVoteDistDiff[recipient];
    }

    function readRecDagVoteDepthDiff(address recipient, uint32 dist) public view returns(uint32){
            return recDagVoteDepthDiff[recipient];
    }


    function readRecDagVoteCount(address recipient, uint32 dist, uint32 height) public view returns(uint32){
            return recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+dist][recDagVoteDepthDiff[recipient]+height];
    }

    function readRecDagVote(address recipient, uint32 dist, uint32 height, uint32 votePos) public view returns(DagVote memory){
            return recDagVote[recipient][recDagVoteDistDiff[recipient]+dist][recDagVoteDepthDiff[recipient]+height][votePos];
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Neighbour tree externals


    // when we first join the tree
    function joinTree(address voter, string calldata name, address recipient) public {
        emit SimpleEventForUpdates(0);

        assert (treeVote[voter] == address(0));
        assert (treeVote[recipient] != address(0));
        assert (recTreeVoteCount[recipient] < 2);

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

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Neighbour tree finder/internals    
    function findRecTreeVotePos(address voter, address recipient) public view returns (bool voted, uint32 votePos) {
        for (uint32 i = 0; i < recTreeVoteCount[recipient]; i++) {
            if (recTreeVote[recipient][i] == voter) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function removeTreeVote(address voter) internal {
        address recipient = treeVote[voter];
        (, uint32 votePos) = findRecTreeVotePos(voter, recipient);

        recTreeVote[recipient][votePos] = recTreeVote[recipient][recTreeVoteCount[recipient]-1];
        recTreeVote[recipient][recTreeVoteCount[recipient]-1]= address(0);
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] - 1;

        // this sets it to one =1, but removeTreeVote is always temporary, there is always only a single root, and a single voter with treeVote =1 . 
        treeVote[voter] = address(1);
    }
 
    function addTreeVote(address voter, address recipient) internal {
        assert (treeVote[voter] == address(1));
        assert (recTreeVoteCount[recipient] < 2);

        treeVote[voter] = recipient;

        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////
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

    // to find the distance between voter and recipient, within maxDistance. 
    // THIS IS ACTUALLY A GLOBAL FUNTION!
    function findDistAtSameDepth(address add1, address add2) public view returns (bool isLocal, uint32 distance) {
        if ( treeVote[add1] == address(0) || treeVote[add2] == address(0)) {
            return (false, 0);
        }

        if (add1 == add2){
            return (true, 0);
        }

        if (treeVote[add1] == address(1) || treeVote[add2] == address(1)) {
            return (false, 0);
        }


        (isLocal, distance) = findDistAtSameDepth(treeVote[add1], treeVote[add2]);

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

        (,  distance)= findDistAtSameDepth(voterAnscenstor, recipient);

        return (isLocal, distance+relDepth, relDepth);
    }

    

/////////////////////////////////////////////////////////////////////////////////////////////////////////
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



/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Dag internals
    ///////////// Setters      
        ///////////// Diffs
            function increaseSentDagVoteDistDiff(address voter, uint32 diff) internal{
                sentDagVoteDistDiff[voter] += diff;
            }

            function decreaseSentDagVoteDistDiff(address voter, uint32 diff) internal{
                sentDagVoteDistDiff[voter] -= diff;
            }

            function increaseRecDagVoteDistDiff(address recipient, uint32 diff) internal{
                recDagVoteDistDiff[recipient] += diff;
            }

            function decreaseRecDagVoteDistDiff(address recipient, uint32 diff) internal{
                recDagVoteDistDiff[recipient] -= diff;
            }

            function increaseSentDagVoteDepthDiff(address voter, uint32 diff) internal{
                sentDagVoteDepthDiff[voter] += diff;
            }

            function decreaseSentDagVoteDepthDiff(address voter, uint32 diff) internal{
                sentDagVoteDepthDiff[voter] -= diff;
            }

            function increaseRecDagVoteDepthDiff(address recipient, uint32 diff) internal{
                recDagVoteDepthDiff[recipient] += diff;
            }

            function decreaseRecDagVoteDepthDiff(address recipient,  uint32 diff) internal{
                recDagVoteDepthDiff[recipient] -= diff;
            }

        ///////////// Counts 

            function increaseSentDagVoteCount(address voter, uint32 dist, uint32 depth, uint32 diff) internal{
                sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+depth] += diff;
            }

            function decreaseSentDagVoteCount(address voter, uint32 dist, uint32 depth, uint32 diff) internal{
                sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+depth] -= diff;
            }

            function increaseRecDagVoteCount(address recipient, uint32 dist, uint32 depth, uint32 diff) internal{
                recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+dist][recDagVoteDepthDiff[recipient]+depth] += diff;
            }

            function decreaseRecDagVoteCount(address recipient, uint32 dist, uint32 depth, uint32 diff) internal{
                recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+dist][recDagVoteDepthDiff[recipient]+depth] -= diff;
            }

        ///////////// Votes

            function setSentDagVote(address voter, uint32 dist, uint32 depth, uint32 sPos, address recipient, uint32 weight, uint32 rPos) internal{
                sentDagVote[voter][sentDagVoteDistDiff[voter]+dist][sentDagVoteDepthDiff[voter]+depth][sPos] = DagVote({id: recipient, weight: weight, posInOther: rPos});
            }

            function setRecDagVote(address recipient, uint32 dist, uint32 depth, uint32 rPos, address voter, uint32 weight, uint32 sPos) internal{
                recDagVote[recipient][sentDagVoteDistDiff[recipient]+dist][recDagVoteDepthDiff[recipient]+depth][rPos] = DagVote({id: voter, weight: weight, posInOther: sPos});
            }

    ///////////// Single vote changes
        //////////// appending a vote

            function sentDagAppend(address voter, uint32 dist, uint32 depth, address recipient, uint32 weight, uint32 rPos ) internal{
                setSentDagVote( voter, dist, depth, readSentDagVoteCount(voter, dist , depth), recipient, weight, rPos); 
                increaseSentDagVoteCount(voter, dist, depth, 1);
            }

            function recDagAppend(address recipient, uint32 dist, uint32 depth, address voter, uint32 weight, uint32 sPos ) internal{
                setRecDagVote(recipient, dist, depth, readRecDagVoteCount(recipient, dist , depth), voter, weight, sPos);
                increaseRecDagVoteCount(recipient, dist, depth, 1);
            }

        //////////// changing position 

            function changePositionSent(address voter, uint32 dist,  uint32 depth, uint32 sPos, uint32 newRPos) internal {
                sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][sPos].posInOther = newRPos;
            }

            function changePositionRec(address recipient, uint32 dist, uint32 depth, uint32 rPos, uint32 newSPos) internal{
                recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][rPos].posInOther = newSPos;
            }   

        //////////// delete and removal functions
            ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.
            
            /// careful, does not delete the opposite! Do not call, call unsafeReplace..  or safeRemove.. instead
            function unsafeDeleteLastSentDagVoteAtDistDepth(address voter, uint32 dist, uint32 depth) internal {
                delete sentDagVote[voter][sentDagVoteDistDiff[voter]+ dist][sentDagVoteDepthDiff[voter]+depth][readSentDagVoteCount(voter, dist, depth-1)];
            }

            /// careful, does not delete the opposite! Do not call, call unsafeReplace..  or safeRemove.. instead
            function unsafeDeleteLastRecDagVoteAtDistDepth(address recipient, uint32 dist, uint32 depth) internal {
                delete recDagVote[recipient][recDagVoteDistDiff[recipient]+ dist][recDagVoteDepthDiff[recipient]+depth][readRecDagVoteCount(recipient, dist, depth-1)];
            }   

            // careful does not delete the opposite! Always call with opposite, or do something with the other vote
            function unsafeReplaceSentDagVoteAtDistDepthPosWithLast(address voter, uint32 dist, uint32 depth, uint32 sPos) internal {
                // find the vote we delete
                DagVote memory sDagVote = readSentDagVote(voter,dist, depth, sPos);
                sentDagVoteTotalWeight[voter] -= sDagVote.weight;

                if (sPos != readSentDagVoteCount(voter, dist, depth)-1) {
                    // if we delete a vote in the middle, we need to copy the last vote to the deleted position
                    (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDistDepth(voter, dist, depth);
                    setSentDagVote(voter, dist, depth, sPos, copiedSentDagVote.id, copiedSentDagVote.weight, copiedSentDagVote.posInOther);
                    changePositionRec(copiedSentDagVote.id , dist, depth, copiedSentDagVote.posInOther, sPos);
                }
                // delete the potentially copied hence duplicate last vote
                unsafeDeleteLastSentDagVoteAtDistDepth(voter, dist, depth);
                decreaseSentDagVoteCount(voter, dist, depth, 1);
            } 

            /// careful, does not delete the opposite!
            function unsafeReplaceRecDagVoteAtDistDepthPosWithLast(address recipient, uint32 dist, uint32 depth, uint32 rPos) internal {
                if (rPos != readRecDagVoteCount(recipient, dist, depth)-1) {
                    (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDistDepth(recipient, dist, depth);
                    setRecDagVote(recipient, dist, depth, rPos, copiedRecDagVote.id, copiedRecDagVote.weight, copiedRecDagVote.posInOther);
                    changePositionSent(copiedRecDagVote.id , dist, depth, copiedRecDagVote.posInOther, rPos); 
                }
                // delete the the potentially copied hence duplicate last vote
                unsafeDeleteLastRecDagVoteAtDistDepth(recipient, dist, depth);
                decreaseRecDagVoteCount(recipient, dist, depth, 1);
            } 

            function safeRemoveSentDagVoteAtDistDepthPos(address voter, uint32 dist, uint32 depth, uint32 sPos) internal {
                DagVote memory sDagVote = readSentDagVote(voter,dist, depth, sPos);
                unsafeReplaceSentDagVoteAtDistDepthPosWithLast(voter, dist, depth, sPos);
                // delete the opposite
                unsafeReplaceRecDagVoteAtDistDepthPosWithLast(sDagVote.id, dist, depth, sDagVote.posInOther);
            }

            function safeRemoveRecDagVoteAtDistDepthPos(address recipient, uint32 dist, uint32 depth, uint32 rPos) internal {
                DagVote memory rDagVote = readRecDagVote(recipient, dist, depth, rPos);
                unsafeReplaceRecDagVoteAtDistDepthPosWithLast(recipient, dist, depth, rPos);
                // delete the opposite
                unsafeReplaceSentDagVoteAtDistDepthPosWithLast(rDagVote.id, dist, depth, rDagVote.posInOther);
            }


    ///////////// Cell removal and handler functions 

        // to remove a row of votes from the sentDagVote array, and the corresponding votes from the recDagVote arrays
        function removeSentDagVoteCell(address voter, uint32 dist, uint32 depth) internal {
            for (uint32 i = readSentDagVoteCount(voter, dist, depth); 0 <= i; i--) {
                safeRemoveSentDagVoteAtDistDepthPos(voter, dist, depth, i);
            }
        }

        // to remove a row of votes from the recDagVote array, and the corresponding votes from the sentDagVote arrays
        function removeRecDagVoteCell(address recipient, uint32 dist, uint32 depth) internal {
            for (uint32 i =  readRecDagVoteCount(recipient, dist, depth); 0 <= i; i--){
                safeRemoveRecDagVoteAtDistDepthPos(recipient, dist, depth, i);
            }
        }

        // merge recDagVoteCell on diagonal right
        function mergeRecDagVoteDiagonalCell(address recipient, uint32 dist) internal {
            for (uint32 i = 0; i < readRecDagVoteCount(recipient, dist, dist); i++) {
                DagVote memory rDagVote = readRecDagVote(recipient, dist, dist, i);
                safeRemoveRecDagVoteAtDistDepthPos(recipient, dist, dist, i);

                recDagAppend(recipient, dist+1, dist, rDagVote.id, rDagVote.weight, readSentDagVoteCount(rDagVote.id, dist+1, dist));
                // there is a -1, as the count has already been increased. 
                sentDagAppend(rDagVote.id, dist+1, dist, recipient, rDagVote.weight, readRecDagVoteCount(recipient, dist+1, dist)-1);
                sentDagVoteTotalWeight[rDagVote.id] += rDagVote.weight;
            }
        }

        function splitRecDagVoteDiagonalCell(address recipient, uint32 dist, address checkAnscestor) internal {
            for (uint32 i = 0; i < readRecDagVoteCount(recipient, dist, dist); i++) {
                DagVote memory rDagVote = readRecDagVote(recipient, dist, dist, i);
                if (findNthParent(rDagVote.id, dist-1) == checkAnscestor){
                    safeRemoveRecDagVoteAtDistDepthPos(recipient, dist, dist, i);

                    // this is over the diagonal, but we will push the frame up
                    recDagAppend(recipient, dist-1, dist, rDagVote.id, rDagVote.weight, readSentDagVoteCount(rDagVote.id, dist-1, dist));
                    // there is a -1, as the count has already been increased. 
                    sentDagAppend(rDagVote.id, dist-1, dist, recipient, rDagVote.weight, readRecDagVoteCount(recipient, dist-1, dist)-1);
                    sentDagVoteTotalWeight[rDagVote.id] += rDagVote.weight;

                }
            }
        }
        
    ///////////// Line  remover nd handler functions
        ///////////// Line removers

          

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


        ///// RecDagVotes Diagonal splitter, mergers

            function mergeRecDagVoteDiagonal(address recipient) internal {
                for (uint32 i = 0; i < MAX_REL_ROOT_DEPTH-1; i++) {
                    mergeRecDagVoteDiagonalCell(recipient, i);
                }
                removeRecDagVoteCell(recipient, MAX_REL_ROOT_DEPTH, MAX_REL_ROOT_DEPTH);
            }

            function splitRecDagVoteDiagonal(address recipient, address checkAnscestor) internal {
                for (uint32 i = 2; i < MAX_REL_ROOT_DEPTH-1; i++) {
                    splitRecDagVoteDiagonalCell(recipient, i, checkAnscestor);
                }
            }
             

        
    
    ////////////////// Combined dag vote handler for rising falling
        
        function handleDagVoteForFalling(address voter, address replacer) internal {

            removeSentDagVoteLineDistEqualsValue(voter, MAX_REL_ROOT_DEPTH);
            decreaseSentDagVoteDepthDiff(voter, 1);
            decreaseSentDagVoteDistDiff(voter, 1);

            splitRecDagVoteDiagonal(voter, replacer);
            removeRecDagVoteLineDepthEqualsValue(voter, 1);
            increaseRecDagVoteDepthDiff(voter, 1);

        }

          function handleDagVoteForRising(address voter) internal {

            removeSentDagVoteLineDepthEqualsValue(voter, 1);
            increaseSentDagVoteDepthDiff(voter, 1);
            increaseSentDagVoteDistDiff(voter, 1);

            mergeRecDagVoteDiagonal(voter);
            decreaseRecDagVoteDepthDiff(voter, 1);

        }

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Dag externals
    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    function addDagVote(address voter, address recipient, uint32 weight) public {
        emit SimpleEventForUpdates(0);

        (bool voted, uint32 dist, uint32 depth, , ) = findSentDagVote(voter, recipient);
        assert (voted == false);

        // add DagVotes. 
        sentDagAppend(voter, dist, depth, recipient, weight, readRecDagVoteCount(recipient, dist, depth));
        recDagAppend(recipient, dist, depth, voter, weight, readSentDagVoteCount(voter, dist, depth));
        //increase sentDagVoteWeights
        sentDagVoteTotalWeight[voter] += weight;
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public {
        emit SimpleEventForUpdates(0);
        
        // find the votes we delete
        (bool voted, uint32 dist, uint32 depth, uint32 sPos, ) = findSentDagVote(voter, recipient);
        assert (voted == true);

        safeRemoveSentDagVoteAtDistDepthPos(voter, dist, depth, sPos);
    }


//////////////////////////////////////////////////////////////////////////////////////////////////////
//// global tree  functions


    //////////////// reputation

        // to calculate the reputation of a voter, i.e. the sum of the votes of the voter and all its descendants
        function calculateReputation(address voter)  public returns (uint256){
            uint256 voterReputation = 0 ;

            for (uint32 dist=0; dist< MAX_REL_ROOT_DEPTH; dist++){    
                for (uint32 depth=0; depth< MAX_REL_ROOT_DEPTH; depth++){
                    for (uint32 count =0; count< readRecDagVoteCount(voter, dist, depth); count++) {
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
    

    
//////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////// global external

    // function changeTreeVote(address voter, address recipient) external {
    //     emit SimpleEventForUpdates(0);

    //     assert (treeVote[voter] != address(0));
    //     assert (treeVote[voter] != address(1));
    //     assert (treeVote[recipient] != address(0));
    //     assert (recTreeVoteCount[recipient] < 2);

    //     // check if local
    //     // if not
    // }
    


    function switchPositionWithParent(address voter) public {
        emit SimpleEventForUpdates(0);

        address parent = treeVote[voter];
        assert (parent != address(0));
        assert (parent != address(1));
        
        uint256 voterRep = calculateReputation(voter);
        uint256 parentRep = calculateReputation(parent);

        if (voterRep > parentRep){
            handleDagVoteForFalling(parent, voter);
            handleDagVoteForRising(voter);
        }
        treeVote[voter] = treeVote[parent];
        treeVote[parent] = voter;
    }

    function leaveTree(address voter) public {
        emit SimpleEventForUpdates(0);

    }
}
