// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Anthill {

    event SimpleEventForUpdates(string str, uint256 randint);

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

    mapping(address => uint32) public sentDagVoteDistDiff; 
    mapping(address => uint32) public sentDagVoteDepthDiff;
    mapping(address => mapping(uint32 => mapping(uint32 => uint32))) public sentDagVoteCount; // voter -> sdist -> depth -> count
    mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote)))) public sentDagVote; // voter -> sdist -> depth -> counter -> DagVote
    
    mapping(address => uint32) public sentDagVoteTotalWeight;
    

    mapping(address => uint32) public recDagVoteDistDiff;
    mapping(address => uint32) public recDagVoteDepthDiff;
    mapping(address => mapping(uint32 => mapping(uint32 => uint32))) public recDagVoteCount; // voter -> rdist -> depth -> count
    mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote)))) public recDagVote; // voter -> rdist -> depth -> counter -> DagVote

    mapping(address => uint256) public reputation;
   
    

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Variable readers 
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

    function readSentDagVoteCount(address voter, uint32 sdist, uint32 depth) public view returns(uint32){
            return sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+sdist][sentDagVoteDepthDiff[voter]+depth];
    }

    function readSentDagVote(address voter, uint32 sdist, uint32 depth, uint32 votePos) public view returns( DagVote memory){
            return sentDagVote[voter][sentDagVoteDistDiff[voter]+sdist][sentDagVoteDepthDiff[voter]+depth][votePos];
    }

    
    function readSentDagVoteTotalWeight(address voter) public view returns( uint32){
            return sentDagVoteTotalWeight[voter];
    }
    // for rec Dag votes

    function readRecDagVoteDistDiff(address recipient) external view returns(uint32){
            return recDagVoteDistDiff[recipient];
    }

    function readRecDagVoteDepthDiff(address recipient) public view returns(uint32){
            return recDagVoteDepthDiff[recipient];
    }


    function readRecDagVoteCount(address recipient, uint32 rdist, uint32 depth) public view returns(uint32){
            return recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+rdist][recDagVoteDepthDiff[recipient]+depth];
    }

    function readRecDagVote(address recipient, uint32 rdist, uint32 depth, uint32 votePos) public view returns(DagVote memory){
            return recDagVote[recipient][recDagVoteDistDiff[recipient]+rdist][recDagVoteDepthDiff[recipient]+depth][votePos];
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Personal tree externals

    // when we first join the tree
    function joinTree(address voter, string calldata name, address recipient) public {
        emit SimpleEventForUpdates("hello", 0);

        assert (treeVote[voter] == address(0));
        assert (treeVote[recipient] != address(0));
        assert (recTreeVoteCount[recipient] < 2);

        treeVote[voter] = recipient;
        names[voter] = name;
        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;

        sentDagVoteDistDiff[voter] = 1000;
        sentDagVoteDepthDiff[voter] = 1000;
        recDagVoteDistDiff[voter] = 1000;
        recDagVoteDepthDiff[voter] = 1000;

    }

    // when we first join the tree without a parent
    function joinTreeAsRoot(address voter, string calldata name) public {
        emit SimpleEventForUpdates("hello", 1);
        
        assert (treeVote[voter] == address(0));
        assert (root == address(0));

        names[voter] = name;
        treeVote[voter] = address(1);
        if (root == address(0)) {
            root = voter;
        }

        sentDagVoteDistDiff[voter] = 1000;
        sentDagVoteDepthDiff[voter] = 1000;
        recDagVoteDistDiff[voter] = 1000;
        recDagVoteDepthDiff[voter] = 1000;
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Personal tree finder 

    function findRecTreeVotePos(address voter, address recipient) public view returns (bool voted, uint32 votePos) {
        for (uint32 i = 0; i < recTreeVoteCount[recipient]; i++) {
            if (recTreeVote[recipient][i] == voter) {
                return (true, i);
            }
        }
        return (false, 0);
    }

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Personal tree internal
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

    function addTreeVoteWithoutCheck(address voter, address recipient) internal {
        assert (treeVote[voter] == address(1));

        treeVote[voter] = recipient;

        recTreeVote[recipient][recTreeVoteCount[recipient]] = voter;
        recTreeVoteCount[recipient] = recTreeVoteCount[recipient] + 1;
    }

    function switchTreeVoteWithParent(address voter) public {
        address parent = treeVote[voter];
        assert (parent != address(0));
        
        address gparent = treeVote[parent]; // this might be 1. 
        removeTreeVote(voter);

        if (readRoot()== parent){
            root= voter;
        } else {
            removeTreeVote(parent);
        }

        addTreeVoteWithoutCheck(voter, gparent);
        addTreeVoteWithoutCheck(parent, voter);

        if (readRoot()== parent){
            root= voter;
        }

        for (uint32 i = 0; i < recTreeVoteCount[parent]; i++) {
            address brother = recTreeVote[parent][i];
            if (brother != voter) {
                removeTreeVote(brother);
                addTreeVoteWithoutCheck(brother, voter);
            }
        }

        for (uint32 i = 0; i < recTreeVoteCount[voter]; i++) {
            address child = recTreeVote[voter][i];
            removeTreeVote(child);
            addTreeVoteWithoutCheck(child, parent);
        }
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

        for (uint32 i = 0; i <= relRootDiff; i++) {
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
    function findDistAtSameDepth(address add1, address add2) public view returns (bool isSameDepth, uint32 distance) {
        if ( treeVote[add1] == address(0) || treeVote[add2] == address(0)) {
            return (false, 0);
        }

        if (add1 == add2){
            return (true, 0);
        }

        if (treeVote[add1] == address(1) || treeVote[add2] == address(1)) {
            return (false, 0);
        }


        (isSameDepth, distance) = findDistAtSameDepth(treeVote[add1], treeVote[add2]);

        // we could remove this check and return isLocal, distance + 1
        if (isSameDepth == true) {
            return (true, distance + 1);
        }

        return (false, 0);
    }

    // 
    function findSDistDepth(address voter, address recipient) public view returns (bool isLocal, uint32 distance, uint32 relDepth){
        if (treeVote[voter] == address(0) || treeVote[recipient] == address(0)) {
            return (false, 0, 0);
        }

        (isLocal,  relDepth) = findRelDepth(voter, recipient);
        if (isLocal == false) {
            return (false, 0, 0);
        }

        address voterAnscenstor = findNthParent(voter, relDepth);

        (,  distance)= findDistAtSameDepth(voterAnscenstor, recipient);

        return (isLocal, distance+relDepth, relDepth);
    }

    

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// DAG finders
    // to check the existence and to find the position of a vote in a given row of the sentDagVote array
    function findSentDagVotePosAtDistDepth(address voter, address recipient, uint32 sdist,  uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        for (uint32 i = 0; i < readSentDagVoteCount(voter, sdist, depth) ; i++) {
            DagVote memory sDagVote = readSentDagVote(voter, sdist, depth, i);
            if (sDagVote.id == recipient) {
                return (true, i, sDagVote);
            }
        }

        return (false, 0, DagVote(address(0), 0, 0));
    }

    // to check the existence and to find the position of a vote in a given row of the recDagVote array
    function findRecDagVotePosAtDistDepth(address voter, address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            for (uint32 i = 0; i < readRecDagVoteCount(recipient, rdist, depth) ; i++) {
                DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, i);
                if (rDagVote.id == voter) {
                    return (true, i, rDagVote);
                }
            }

            return (false, 0, DagVote(address(0), 0, 0));
    }

    function findLastSentDagVoteAtDistDepth(address voter, uint32 sdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        
        uint32 count = readSentDagVoteCount(voter, sdist, depth);

        if (count == 0) {
            return (false, 0, DagVote(address(0), 0, 0));
        }

        return (true, count-1, readSentDagVote(voter, sdist ,depth, count-1));
    }

    function findLastRecDagVoteAtDistDepth(address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
       
        uint32 count = readRecDagVoteCount(recipient, rdist, depth);

        if (count == 0) {
            return (false, 0, DagVote(address(0), 0, 0));
        }

        return (true, count-1, readRecDagVote(recipient,rdist,  depth, count-1));
    }

    // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
    function findSentDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 sdist,  uint32 depth, uint32 votePos, DagVote memory dagVote){ 
        bool isLocal;
        (isLocal,  sdist,  depth) = findSDistDepth(voter, recipient);
        
        if ((isLocal == false) || (depth == 0)) {
            return (false, false, 0, 0, 0,  DagVote(address(0), 0, 0));
        }

        (voted,  votePos, dagVote) = findSentDagVotePosAtDistDepth(voter, recipient, sdist, depth);

        return (true, voted, sdist, depth, votePos, dagVote);
    }

    // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
    function findRecDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 rdist, uint32 depth, uint32 votePos, DagVote memory dagVote){
            bool isLocal;
            uint32 sdist;

            ( isLocal, sdist, depth) = findSDistDepth(voter, recipient);
            rdist= sdist - depth;

            if ((isLocal == false) || (depth == 0)) {
                return (false, false, 0, 0, 0,  DagVote(address(0), 0, 0));
            }

            (voted, votePos, dagVote) = findRecDagVotePosAtDistDepth(voter, recipient, rdist, depth);

            return (true, voted, rdist,  depth, votePos, dagVote);
    }



/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Dag internals. Core logic. 
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

            function increaseSentDagVoteCount(address voter, uint32 sdist, uint32 depth, uint32 diff) internal{
                sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+sdist][sentDagVoteDepthDiff[voter]+depth] += diff;
            }

            function decreaseSentDagVoteCount(address voter, uint32 sdist, uint32 depth, uint32 diff) internal{
                sentDagVoteCount[voter][sentDagVoteDistDiff[voter]+sdist][sentDagVoteDepthDiff[voter]+depth] -= diff;
            }

            function increaseRecDagVoteCount(address recipient, uint32 rdist, uint32 depth, uint32 diff) internal{
                recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+rdist][recDagVoteDepthDiff[recipient]+depth] += diff;
            }

            function decreaseRecDagVoteCount(address recipient, uint32 rdist, uint32 depth, uint32 diff) internal{
                recDagVoteCount[recipient][recDagVoteDistDiff[recipient]+rdist][recDagVoteDepthDiff[recipient]+depth] -= diff;
            }

        ///////////// Votes

            function setSentDagVote(address voter, uint32 sdist, uint32 depth, uint32 sPos, address recipient, uint32 weight, uint32 rPos) internal{
                sentDagVote[voter][sentDagVoteDistDiff[voter]+sdist][sentDagVoteDepthDiff[voter]+depth][sPos] = DagVote({id: recipient, weight: weight, posInOther: rPos});
            }

            function setRecDagVote(address recipient, uint32 rdist, uint32 depth, uint32 rPos, address voter, uint32 weight, uint32 sPos) internal{
                recDagVote[recipient][recDagVoteDistDiff[recipient]+rdist][recDagVoteDepthDiff[recipient]+depth][rPos] = DagVote({id: voter, weight: weight, posInOther: sPos});
            }

    ///////////// Single vote changes
        //////////// appending a vote

            function sentDagAppend(address voter, uint32 sdist, uint32 depth, address recipient, uint32 weight, uint32 rPos ) internal{
                setSentDagVote( voter, sdist, depth, readSentDagVoteCount(voter, sdist , depth), recipient, weight, rPos); 
                increaseSentDagVoteCount(voter, sdist, depth, 1);
            }

            function recDagAppend(address recipient, uint32 rdist, uint32 depth, address voter, uint32 weight, uint32 sPos ) public{
                setRecDagVote(recipient, rdist, depth, readRecDagVoteCount(recipient, rdist , depth), voter, weight, sPos);
                increaseRecDagVoteCount(recipient, rdist, depth, 1);
            }

            function combinedDagAppend(address voter, address recipient,  uint32 sdist, uint32 depth, uint32 weight) internal{
                sentDagAppend(voter, sdist, depth, recipient, weight, readRecDagVoteCount(recipient, sdist-depth, depth));
                recDagAppend(recipient, sdist-depth, depth, voter, weight,  readSentDagVoteCount(voter, sdist, depth)-1);
            }

        //////////// changing position

            function changePositionSent(address voter, uint32 sdist,  uint32 depth, uint32 sPos, uint32 newRPos) internal {
                sentDagVote[voter][sentDagVoteDistDiff[voter]+ sdist][sentDagVoteDepthDiff[voter]+depth][sPos].posInOther = newRPos;
            }

            function changePositionRec(address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newSPos) internal{
                recDagVote[recipient][recDagVoteDistDiff[recipient]+ rdist][recDagVoteDepthDiff[recipient]+depth][rPos].posInOther = newSPos;
            }   

        

        //////////// delete and removal functions
            ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.
            
            /// careful, does not delete the opposite! Do not call, call unsafeReplace..  or safeRemove.. instead
            function unsafeDeleteLastSentDagVoteAtDistDepth(address voter, uint32 sdist, uint32 depth) internal {
                delete sentDagVote[voter][sentDagVoteDistDiff[voter]+ sdist][sentDagVoteDepthDiff[voter]+depth][readSentDagVoteCount(voter, sdist, depth)-1];
            }

            /// careful, does not delete the opposite! Do not call, call unsafeReplace..  or safeRemove.. instead
            function unsafeDeleteLastRecDagVoteAtDistDepth(address recipient, uint32 rdist, uint32 depth) internal {
                delete recDagVote[recipient][recDagVoteDistDiff[recipient]+ rdist][recDagVoteDepthDiff[recipient]+depth][readRecDagVoteCount(recipient, rdist, depth)-1];
            }   

            // careful does not delete the opposite! Always call with opposite, or do something with the other vote
            function unsafeReplaceSentDagVoteAtDistDepthPosWithLast(address voter, uint32 sdist, uint32 depth, uint32 sPos) internal {
                // find the vote we delete
                DagVote memory sDagVote = readSentDagVote(voter, sdist, depth, sPos);
                
                sentDagVoteTotalWeight[voter] -= sDagVote.weight;
                if (sPos!= readSentDagVoteCount(voter, sdist, depth)-1) {
                    // if we delete a vote in the middle, we need to copy the last vote to the deleted position
                    (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDistDepth(voter, sdist, depth);
                    setSentDagVote(voter, sdist, depth, sPos, copiedSentDagVote.id, copiedSentDagVote.weight, copiedSentDagVote.posInOther);
                    changePositionRec(copiedSentDagVote.id , sdist-depth, depth, copiedSentDagVote.posInOther, sPos);
                }
                
                // delete the potentially copied hence duplicate last vote
                unsafeDeleteLastSentDagVoteAtDistDepth(voter, sdist, depth);
                decreaseSentDagVoteCount(voter, sdist, depth, 1);
            } 

            /// careful, does not delete the opposite!
            function unsafeReplaceRecDagVoteAtDistDepthPosWithLast(address recipient, uint32 rdist, uint32 depth, uint32 rPos) public {
                if (rPos != readRecDagVoteCount(recipient, rdist, depth)-1) {
                    (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDistDepth(recipient, rdist, depth);
                    setRecDagVote(recipient, rdist, depth, rPos, copiedRecDagVote.id, copiedRecDagVote.weight, copiedRecDagVote.posInOther);
                    changePositionSent(copiedRecDagVote.id , rdist+depth, depth, copiedRecDagVote.posInOther, rPos); 
                }

                // delete the the potentially copied hence duplicate last vote
                unsafeDeleteLastRecDagVoteAtDistDepth(recipient, rdist, depth);
                decreaseRecDagVoteCount(recipient, rdist, depth, 1);
            } 

            function safeRemoveSentDagVoteAtDistDepthPos(address voter, uint32 sdist, uint32 depth, uint32 sPos) internal {
                DagVote memory sDagVote = readSentDagVote(voter,sdist, depth, sPos);
                unsafeReplaceSentDagVoteAtDistDepthPosWithLast(voter, sdist, depth, sPos);
                // delete the opposite
                unsafeReplaceRecDagVoteAtDistDepthPosWithLast(sDagVote.id, sdist-depth, depth, sDagVote.posInOther);
            }

            function safeRemoveRecDagVoteAtDistDepthPos(address recipient, uint32 rdist, uint32 depth, uint32 rPos) internal {
                DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, rPos);
                unsafeReplaceRecDagVoteAtDistDepthPosWithLast(recipient, rdist, depth, rPos);
                // delete the opposite
                unsafeReplaceSentDagVoteAtDistDepthPosWithLast(rDagVote.id, rdist+depth, depth, rDagVote.posInOther);
            }

        //////////// change dist and depth
            function changeDistDepthSent(address voter, uint32 sdist, uint32 depth, uint32 sPos, address recipient, uint32 rPos, uint32 weight, uint32 newSDist, uint32 newDepth) public{
                // here it is ok to use unsafe, as the the vote is moved, not removed
                unsafeReplaceSentDagVoteAtDistDepthPosWithLast(voter, sdist, depth, sPos);                
                sentDagAppend(voter, newSDist, newDepth, recipient, weight, rPos);
                sentDagVoteTotalWeight[voter] += weight;
            }

            function changeDistDepthRec(address recipient, uint32 rdist, uint32 depth, uint32 rPos, address voter, uint32 sPos, uint32 weight, uint32 newRDist, uint32 newDepth) public{
                // here it is ok to use unsafe, as the the vote is moved, not removed
                unsafeReplaceRecDagVoteAtDistDepthPosWithLast(recipient, rdist, depth, rPos);                
                recDagAppend(recipient, newRDist, newDepth, voter, weight, sPos);
            }

    ///////////// Cell removal and handler functions 
        /////////// removal 
            // to remove a row of votes from the sentDagVote array, and the corresponding votes from the recDagVote arrays
            function removeSentDagVoteCell(address voter, uint32 sdist, uint32 depth) internal {
                if (readSentDagVoteCount(voter, sdist, depth) == 0) {
                    return;
                }
                for (uint32 i = readSentDagVoteCount(voter, sdist, depth); 1 <= i; i--) {
                    safeRemoveSentDagVoteAtDistDepthPos(voter, sdist, depth, i-1);
                }
            }

            // to remove a row of votes from the recDagVote array, and the corresponding votes from the sentDagVote arrays
            function removeRecDagVoteCell(address recipient, uint32 rdist, uint32 depth) public {
                if (readRecDagVoteCount(recipient, rdist, depth) == 0) {
                    return;
                }
                for (uint32 i =  readRecDagVoteCount(recipient, rdist, depth); 1 <= i; i--){
                    safeRemoveRecDagVoteAtDistDepthPos(recipient, rdist, depth, i-1);
                }
            }

        
        
        /////////// dist depth on opposite 
            function changeDistDepthFromSentCellOnOp(address voter, uint32 sdist, uint32 depth, uint32 oldSDist, uint32 oldDepth) internal {
                for (uint32 i = 0; i < readSentDagVoteCount(voter, sdist, depth); i++) {
                    DagVote memory sDagVote = readSentDagVote(voter, sdist, depth, i);
                    changeDistDepthRec(sDagVote.id, oldSDist-oldDepth, oldDepth, sDagVote.posInOther, voter, i, sDagVote.weight, sdist-depth, depth);
                    changePositionSent(voter, sdist, depth, i, readRecDagVoteCount(sDagVote.id, sdist-depth, depth)-1);
                }
            }

            function changeDistDepthFromRecCellOnOp(address recipient, uint32 rdist, uint32 depth, uint32 oldRDist, uint32 oldDepth) public {
                for (uint32 i =  readRecDagVoteCount(recipient, rdist, depth); 0 < i ; i--) {
                    
                    
                    DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, i-1);

                    emit SimpleEventForUpdates("in changeDistDepth from Cell", uint160(recipient));
                    emit SimpleEventForUpdates("voter", uint160(rDagVote.id));
                    emit SimpleEventForUpdates("vote pos", uint160(rDagVote.posInOther));
                    emit SimpleEventForUpdates("vote weight", uint160(rDagVote.weight));

                    emit SimpleEventForUpdates("rdist", uint160(rdist));
                    emit SimpleEventForUpdates("depth", uint160(depth));
                    emit SimpleEventForUpdates("oldRDist", uint160(oldRDist));
                    emit SimpleEventForUpdates("i", uint160(i));


                    changeDistDepthSent(rDagVote.id, oldRDist+oldDepth, oldDepth, rDagVote.posInOther, recipient, i-1, rDagVote.weight, rdist+depth, depth);
                    changePositionRec(recipient, rdist, depth, i-1, readSentDagVoteCount(rDagVote.id, rdist+depth, depth)-1);
                }
            }
        
        /////////// move cell

            function moveSentDagVoteCell(address voter, uint32 sdist, uint32 depth, uint32 newSDist, uint32 newDepth) internal {
                for (uint32 i = readSentDagVoteCount(voter, sdist, depth); 0< i; i--) {
                    DagVote memory sDagVote = readSentDagVote(voter, sdist, depth, i-1);
                    safeRemoveSentDagVoteAtDistDepthPos(voter, sdist, depth, i-1);
                    combinedDagAppend(voter, sDagVote.id, newSDist, newDepth, sDagVote.weight);
                }
            }

             function moveRecDagVoteCell(address recipient, uint32 rdist, uint32 depth, uint32 newRDist, uint32 newDepth) internal {
                for (uint32 i = readRecDagVoteCount(recipient, rdist, depth); 0< i; i--) {
                    DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, i-1);
                    safeRemoveRecDagVoteAtDistDepthPos(recipient, rdist, depth, i-1);
                    combinedDagAppend(rDagVote.id, recipient,  newRDist+newDepth, newDepth, rDagVote.weight);
                }
            }
    ///////////// Line  remover and sorter functions
        ///////////// Line removers

            function removeSentDagVoteLineDepthEqualsValue(address voter, uint32 value) internal {
                for (uint32 dist = value; dist <= MAX_REL_ROOT_DEPTH ; dist++) {
                    removeSentDagVoteCell(voter, dist, value);
                }
            }

            function removeRecDagVoteLineDepthEqualsValue(address voter, uint32 value) internal {
                for (uint32 dist = 0; dist < MAX_REL_ROOT_DEPTH-value; dist++) {
                    removeRecDagVoteCell(voter, dist, value);
                }
            }

            function removeSentDagVoteLineDistEqualsValue(address voter, uint32 value) internal {
                for (uint32 depth = 1; depth <= value ; depth++) {
                    removeSentDagVoteCell(voter, value, depth);
                }
            }


        ///////////// Sort Cell into line
            function sortSentDagVoteCell(address voter, uint32 sdist, uint32 depth, address anscestorAtDepth) internal {
                for (uint32 i = readSentDagVoteCount(voter, sdist, depth); 0 < i ; i--) {
                    DagVote memory sDagVote = readSentDagVote(voter, sdist, depth, i-1);

                    (, uint32 distFromAnsc)= findDistAtSameDepth(sDagVote.id, anscestorAtDepth);
                    safeRemoveSentDagVoteAtDistDepthPos(voter, sdist, depth, i-1);
                    combinedDagAppend(voter, sDagVote.id, distFromAnsc + depth, depth, sDagVote.weight);
                }
            }

            function sortRecDagVoteCell(address recipient, uint32 rdist, uint32 depth,  address newTreeVote) internal {
                for (uint32 i = readRecDagVoteCount(recipient, rdist, depth); 0 < i; i--) {
                    DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, i-1);

                    // if newTreeVote is 1, then findNthParent does not return it, as it stays inside the tree. 
                    address anscestorOfSenderAtDepth = treeVote[findNthParent(rDagVote.id, depth)];

                    bool sameHeight ;
                    uint32 distFromNewTreeVote;
                    if ((anscestorOfSenderAtDepth == newTreeVote) && (newTreeVote == address(1))) {
                        sameHeight = true;
                        distFromNewTreeVote = 0;
                        // we got to root, we need to check we are at the correct height. 
                        assert (findNthParent(rDagVote.id, depth)== readRoot());
                    } else {
                        (sameHeight, distFromNewTreeVote)= findDistAtSameDepth(newTreeVote, anscestorOfSenderAtDepth);
                    }

                    assert(sameHeight);
                    safeRemoveRecDagVoteAtDistDepthPos(recipient, rdist, depth, i-1);
                    combinedDagAppend(rDagVote.id, recipient, distFromNewTreeVote +depth+1, depth, rDagVote.weight);
                }
            }

            function sortRecDagVoteCellDescendants(address recipient, uint32 depth, address replaced) internal {
                for (uint32 i = readRecDagVoteCount(recipient, 1, depth); 0 < i; i--) {
                    DagVote memory rDagVote = readRecDagVote(recipient, 1, depth, i - 1);

                    address anscestorAtDepth = findNthParent(rDagVote.id, depth);

                    // emit SimpleEventForUpdates("sortCellDesc rec: ", uint160(recipient));
                    // emit SimpleEventForUpdates(" repla: ", uint160(replaced));
                    // emit SimpleEventForUpdates(" depth", uint160(depth));
                    // emit SimpleEventForUpdates(" rdv.id", uint160(rDagVote.id));
                    // emit SimpleEventForUpdates(" anscestor", uint160(anscestorAtDepth));
                    // emit SimpleEventForUpdates("sortCellDesc: ", uint160(recipient));
                    // emit SimpleEventForUpdates("sortCellDesc: ", uint160(recipient));

                    if (anscestorAtDepth == replaced) {
                        safeRemoveRecDagVoteAtDistDepthPos(recipient, 1, depth, i-1);
                        combinedDagAppend(rDagVote.id, recipient, 1+depth-1, depth, rDagVote.weight);
                    }
                }
            }
    
    ///////////// Area/whole triangle changers
        ///////////// Removers
            //////////// complete triangles
                function removeSentDagVoteComplete(address voter) public {
                    for (uint32 dist = 1; dist <=MAX_REL_ROOT_DEPTH; dist ++){
                        for (uint32 depth=1; depth<= dist ; depth++){
                            removeSentDagVoteCell(voter, dist , depth);
                        }
                    }
                }

                function removeRecDagVoteComplete(address recipient) public {
                    for (uint32 dist=0; dist<MAX_REL_ROOT_DEPTH; dist++){
                        for (uint32 depth=1; depth<=MAX_REL_ROOT_DEPTH -dist; depth++){
                            removeRecDagVoteCell(recipient, dist, depth);
                        }
                    }
                }

            //////////// function removeRecDagVote above/below a line

                function removeSentDagVoteAboveHeight(address voter, uint32 depth) internal {
                    for (uint32 dist =1; dist <=MAX_REL_ROOT_DEPTH; dist ++){
                        for (uint32 depthIter=depth+1; depthIter<= dist ; depthIter++){
                            removeSentDagVoteCell(voter, dist , depthIter);
                        }
                    }
                }

                function removeSentDagVoteBelowHeight(address voter, uint32 depth) internal {
                    for (uint32 i=1; i<=MAX_REL_ROOT_DEPTH; i++){
                        for (uint32 j=1; j<=depth; j++){
                            removeSentDagVoteCell(voter, i, j);
                        }
                    }
                }

                function removeSentDagVoteFurtherThanDist(address voter, uint32 dist) internal {
                    for (uint32 i=dist ; i<=MAX_REL_ROOT_DEPTH; i++){
                        for (uint32 j=1; j<=i; j++){
                            removeSentDagVoteCell(voter, i, j);
                        }
                    }
                }

                function removeRecDagVoteAboveDepth(address voter, uint32 depth) internal {
                    for (uint32 i=0; i<MAX_REL_ROOT_DEPTH; i++){
                        for (uint32 j=1; j<depth; j++){
                            removeRecDagVoteCell(voter, i, j);
                        }
                    }
                }

                function removeRecDagVoteBelowDepth(address voter, uint32 depth) internal {
                    for (uint32 i= 0; i< MAX_REL_ROOT_DEPTH - depth; i++){
                        for (uint32 j=depth; j<= MAX_REL_ROOT_DEPTH; j++){
                            removeRecDagVoteCell(voter, i, j);
                        }
                    }
                }

                


        
        ///////////// Depth and pos change across graph
            function increaseDistDepthFromSentOnOpFalling(address voter, uint32 sdistDiff, uint32 depthDiff) internal {
                for (uint32 dist = 1; dist <= MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= dist; depth++) {
                        changeDistDepthFromSentCellOnOp(voter, dist, depth, dist-sdistDiff, depth-depthDiff);
                    }
                }
            }

            function decreaseDistDepthFromSentOnOpRising(address voter, uint32 sdistDiff, uint32 depthDiff) internal {
                for (uint32 dist = 1; dist <= MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= dist; depth++) {
                        changeDistDepthFromSentCellOnOp(voter, dist, depth, dist+sdistDiff, depth+depthDiff);
                    }
                }
            }

            function changeDistDepthFromRecOnOpFalling(address voter, uint32 diff) internal {
                for (uint32 dist = 0; dist < MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= MAX_REL_ROOT_DEPTH- dist; depth++) {
                        changeDistDepthFromRecCellOnOp(voter, dist, depth, dist-diff, depth+diff);
                    }
                }
            }

            function changeDistDepthFromRecOnOpRising(address voter, uint32 diff) internal {
                for (uint32 dist = 0; dist < MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= MAX_REL_ROOT_DEPTH- dist; depth++) {
                        changeDistDepthFromRecCellOnOp(voter, dist, depth, dist+diff, depth-diff);
                    }
                }
            }

        ///////////// Movers
            function moveSentDagVoteUpRightFalling(address voter, uint32 diff) internal {
                decreaseSentDagVoteDepthDiff(voter, diff);
                decreaseSentDagVoteDistDiff(voter, diff);
                increaseDistDepthFromSentOnOpFalling(voter, diff, diff);
            }

            function moveSentDagVoteDownLeftRising(address voter, uint32 diff) internal {
                increaseSentDagVoteDepthDiff(voter, diff);
                increaseSentDagVoteDistDiff(voter, diff);
                decreaseDistDepthFromSentOnOpRising(voter, diff, diff);
            }

            function moveRecDagVoteUpRightFalling(address voter, uint32 diff) internal {
                decreaseRecDagVoteDistDiff(voter, diff);
                increaseRecDagVoteDepthDiff(voter, diff);
                changeDistDepthFromRecOnOpFalling(voter, diff);
            }

            function moveRecDagVoteDownLeftRising(address voter, uint32 diff) public {
                increaseRecDagVoteDistDiff(voter, diff);
                decreaseRecDagVoteDepthDiff(voter, diff);
                changeDistDepthFromRecOnOpRising(voter, diff);
            }
        ///////////// Collapsing to, and sorting from columns

            function collapseSentDagVoteIntoColumn(address voter, uint32 sdistDestination) public {
                for (uint32 sdist = 1; sdist < sdistDestination; sdist++) {
                    for (uint32 depth = 1; depth <= sdist; depth++){ 
                        moveSentDagVoteCell(voter, sdist, depth, sdistDestination, depth);
                    }
                }
            }            

            function collapseRecDagVoteIntoColumn( address voter, uint32 rdistDestination) public {
                for (uint32 rdist = 0; rdist <  rdistDestination; rdist++) {
                    for (uint32 depth = 1; depth <=MAX_REL_ROOT_DEPTH- rdist; depth++){ 
                        if (depth <= MAX_REL_ROOT_DEPTH - rdistDestination){
                            moveRecDagVoteCell(voter, rdist, depth, rdistDestination, depth);
                        } else {
                            removeRecDagVoteCell(voter, rdist, depth);
                        }
                    }
                }
            }

            function sortSentDagVoteColumn(address voter, uint32 sdist, address newTreeVote) public {
                address anscestorAtDepth = newTreeVote;
                for (uint32 depth = 1; depth <= sdist; depth++) {
                    sortSentDagVoteCell(voter, sdist, depth, anscestorAtDepth);
                    anscestorAtDepth = treeVote[anscestorAtDepth];
                }
            }

            function sortRecDagVoteColumn( address recipient, uint32 rdist, address newTreeVote) public {
                for (uint32 depth = 1; depth <= MAX_REL_ROOT_DEPTH-rdist; depth++) {
                    sortRecDagVoteCell(recipient, rdist, depth,  newTreeVote);                    
                }
            }

            function sortRecDagVoteColumnDescendants( address recipient, address replaced) public {
                 for (uint32 depth = 1; depth <= MAX_REL_ROOT_DEPTH-1; depth++) {
                    sortRecDagVoteCellDescendants(recipient, depth, replaced);
                } 
            }

        ///////////// Combined dag Square vote handler for rising falling, a certain depth, with passing the new recipient in for selction    

            function handleDagVoteMoveRise(address voter, address recipient, address replaced, uint32 moveDist, uint32 depthDiff ) public {
                // sent 
                removeSentDagVoteBelowHeight(voter, depthDiff);
                collapseSentDagVoteIntoColumn(voter, moveDist);
                moveSentDagVoteDownLeftRising(voter, depthDiff);
                sortSentDagVoteColumn(voter, moveDist - depthDiff, recipient);  

                // // recDagVote
                removeRecDagVoteBelowDepth(voter, MAX_REL_ROOT_DEPTH - moveDist);         
                collapseRecDagVoteIntoColumn(voter, moveDist);
                moveRecDagVoteDownLeftRising(voter, depthDiff);            
                // sortRecDagVoteColumn(voter, moveDist-depthDiff,  recipient);
                
                // if (replaced != address(0)) {
                //     sortRecDagVoteColumnDescendants(voter, replaced);
                // } 
            }

            function handleDagVoteMoveFall(address voter, address recipient, address replaced, uint32 moveDist, uint32 depthDiff) public {
                // sent 
                removeSentDagVoteFurtherThanDist(voter, MAX_REL_ROOT_DEPTH - depthDiff);
                collapseSentDagVoteIntoColumn(voter, moveDist);
                moveSentDagVoteUpRightFalling(voter, depthDiff);
                sortSentDagVoteColumn(voter, moveDist + depthDiff, recipient);  

                // recDagVote
                removeRecDagVoteBelowDepth(voter, MAX_REL_ROOT_DEPTH - moveDist);
                removeRecDagVoteAboveDepth(voter, depthDiff);         
        
                collapseRecDagVoteIntoColumn(voter, moveDist);
                moveRecDagVoteUpRightFalling(voter, depthDiff);            
                sortRecDagVoteColumn(voter, moveDist+depthDiff, recipient);
                
                if (replaced != address(0)) {
                    sortRecDagVoteColumnDescendants(voter, replaced);
                } 
            }

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Dag externals
    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    function addDagVote(address voter, address recipient, uint32 weight) public {
        emit SimpleEventForUpdates("hello", 0);

        (bool votable, bool voted, uint32 sdist, uint32 depth, , ) = findSentDagVote(voter, recipient);
        assert ((votable) && (voted == false));

        // add DagVotes. 
        combinedDagAppend(voter, recipient, sdist, depth, weight);
        sentDagVoteTotalWeight[voter] += weight;
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public {
        emit SimpleEventForUpdates("hello", 0);
        
        // find the votes we delete
        (, bool voted, uint32 sdist, uint32 depth, uint32 sPos, ) = findSentDagVote(voter, recipient);
        assert (voted == true);

        safeRemoveSentDagVoteAtDistDepthPos(voter, sdist, depth, sPos);
    }


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Global readers 

    function readDepth(address voter) public view returns(uint32){
        if (treeVote[voter] == address(0)) return 0;
        if (treeVote[voter] == address(1)) return 0;

        return readDepth(treeVote[voter]) + 1;
    } 

    // to calculate the reputation of a voter, i.e. the sum of the votes of the voter and all its descendants
    function calculateReputation(address voter)  public returns (uint256){
        uint256 voterReputation = 0 ;
        if (voter == address(0)) return 0;

        for (uint32 dist=0; dist< MAX_REL_ROOT_DEPTH; dist++){    
            for (uint32 depth=0; depth<= MAX_REL_ROOT_DEPTH-dist; depth++){
                for (uint32 count =0; count< readRecDagVoteCount(voter, dist, depth); count++) {
                DagVote memory rDagVote = readRecDagVote(voter, dist, depth, count);
                    // emit SimpleEventForUpdates("hello", 9999999999999999999999999);
                    // emit SimpleEventForUpdates("hello", uint256(uint160(voter)));
                    // emit SimpleEventForUpdates("hello", uint256(uint160(rDagVote.id)));
                    // emit SimpleEventForUpdates("hello", uint256(uint160(dist)));
                    // emit SimpleEventForUpdates("hello", uint256(uint160(depth)));
                    // emit SimpleEventForUpdates("hello", uint256(uint160(count)));


                    // the above line removes the div by zero error, but it is not the correct solution, as we should not have a zero address in the first place. 
                    voterReputation += calculateReputation(rDagVote.id)*(rDagVote.weight)/ sentDagVoteTotalWeight[rDagVote.id];
                }
            }
        }
        // for the voter themselves
        voterReputation += 10**decimalPoint;
        reputation[voter] = voterReputation;
        return voterReputation;
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Global internal
    
    function pullUpBranch(address pulledVoter) public {
        // if (readRecTreeVoteCount(pulledVoter)==0) return; 
        // emit SimpleEventForUpdates("pulling up branch for", uint160(pulledVoter));
        address firstChild = readRecTreeVote(pulledVoter, 0);
        address secondChild = readRecTreeVote(pulledVoter, 1);

        if (firstChild!=address(0)){
            
            handleDagVoteMoveRise(firstChild, pulledVoter, pulledVoter, 1, 1);
        
            pullUpBranch(firstChild);    

            if (secondChild != address(0)){
                removeTreeVote(secondChild);
                addTreeVote(secondChild, firstChild);
            }
        }

    }

    function handleLeavingVoterBranch(address voter) public {
        address parent = treeVote[voter];

        removeTreeVote(voter);
        treeVote[voter]=address(0);

        address firstChild = readRecTreeVote(voter, 0);
        address secondChild = readRecTreeVote(voter, 1);

        if (firstChild!=address(0)){
            
            handleDagVoteMoveRise(firstChild, parent, voter, 1, 1);

            removeTreeVote(firstChild);
            addTreeVote(firstChild, parent);

            pullUpBranch(firstChild);


            if (secondChild != address(0)){
                removeTreeVote(secondChild);
                addTreeVote(secondChild, firstChild);
            }

        }
    }
    
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Global external

    
    function leaveTree(address voter) public {
        emit SimpleEventForUpdates("hello", 0);
        
        removeSentDagVoteComplete(voter);
        removeRecDagVoteComplete(voter);

        handleLeavingVoterBranch(voter);
    }


    function switchPositionWithParent(address voter) public {
        emit SimpleEventForUpdates("hello", 0);

        address parent = treeVote[voter];
        assert (parent != address(0));
        assert (parent != address(1));
        address gparent = treeVote[parent];
        
        uint256 voterRep = calculateReputation(voter);
        uint256 parentRep = calculateReputation(parent);

        assert (voterRep > parentRep);
        
        handleDagVoteMoveFall(parent, parent, voter, 1, 1);
        handleDagVoteMoveRise(voter, gparent, parent, 1, 1);
        
        switchTreeVoteWithParent(voter);
    }

    function changeTreeVote(address voter, address recipient) external {
        emit SimpleEventForUpdates("hello", 0);

        assert (treeVote[voter] != address(0));
        assert (treeVote[voter] != address(1));

        assert (treeVote[recipient] != address(0));
        assert (recTreeVoteCount[recipient] < 2);

        (address relRoot, ) = findRelRoot(voter);
        (bool isLowerOrEqual, uint32 lowerDist, uint32 lowerDepth) = findSDistDepth(recipient, voter);
        bool isAnscestor = (isLowerOrEqual &&(lowerDist == lowerDepth));
        (bool isSimilar, uint32 simDist, uint32 simDepth) = findSDistDepth(voter, recipient);
        (bool isHigher, uint32 higherDistToRelRoot, uint32 higherDepthToRelRoot) = findSDistDepth(recipient, relRoot);
        uint32 higherDepth = MAX_REL_ROOT_DEPTH - higherDepthToRelRoot;
        uint32 higherDist = higherDistToRelRoot + higherDepth;

        if (isAnscestor){
            handleDagVoteMoveFall(voter, recipient, address(0), lowerDist, lowerDepth);
        } else if (isLowerOrEqual){
            handleDagVoteMoveFall(voter, recipient, address(0), lowerDist, lowerDepth);
        } else if (isSimilar){
            handleDagVoteMoveRise(voter, recipient, address(0), simDist, simDepth);
        } else if ((isHigher) && (higherDepth > 1)){
            handleDagVoteMoveRise(voter, recipient, address(0), higherDist, higherDepth);
        }  else {
            removeSentDagVoteComplete(voter);
            removeRecDagVoteComplete(voter);            
        }
        // handle tree votes
        handleLeavingVoterBranch(voter);
        addTreeVote(voter, recipient);
    }
}
