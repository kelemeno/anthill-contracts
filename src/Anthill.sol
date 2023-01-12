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

    mapping(address => uint32) public sentDagVoteDistDiff; // voter -> dist -> depthdiff
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
//// Personal tree finder/internals    
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
    // function findRecDagVotePosAtDistDepth(address voter, address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        //     for (uint32 i = 0; i < readRecDagVoteCount(recipient, rdist, depth) ; i++) {
        //         DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, i);
        //         if (rDagVote.id == voter) {
        //             return (true, i, rDagVote);
        //         }
        //     }

        //     return (false, 0, DagVote(address(0), 0, 0));
    // }

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
    // function findRecDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 rdist, uint32 depth, uint32 votePos, DagVote memory dagVote){
        //     bool isLocal;
        //     uint32 sdist;

        //     ( isLocal, sdist, depth) = findSDistDepth(voter, recipient);
        //     rdist= sdist - depth;

        //     if ((isLocal == false) || (depth == 0)) {
        //         return (false, false, 0, 0, 0,  DagVote(address(0), 0, 0));
        //     }

        //     (voted, votePos, dagVote) = findRecDagVotePosAtDistDepth(voter, recipient, rdist, depth);

        //     return (true, voted, rdist,  depth, votePos, dagVote);
    // }



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

            // function increaseRecDagVoteDistDiff(address recipient, uint32 diff) internal{
                // recDagVoteDistDiff[recipient] += diff;
            // }

            // function decreaseRecDagVoteDistDiff(address recipient, uint32 diff) internal{
                //     recDagVoteDistDiff[recipient] -= diff;
            // }

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

        /////////// merge split
            // merge recDagVoteCell on diagonal right
            function mergeRecDagVoteDiagonalCell(address recipient, uint32 rdist) public {
            //     if (readRecDagVoteCount(recipient, rdist, rdist) == 0) {
            //         return;
            //     }         
            //     for (uint32 i = readRecDagVoteCount(recipient, rdist, rdist); 1 <= i; i--) {

            //         DagVote memory rDagVote = readRecDagVote(recipient, rdist, rdist, i-1);

            //         safeRemoveRecDagVoteAtDistDepthPos(recipient, rdist, rdist, i-1);
            //         combinedDagAppend(rDagVote.id, recipient, rdist+1, rdist, rDagVote.weight);
            //         sentDagVoteTotalWeight[rDagVote.id] += rDagVote.weight;
            //     }
            }

            function splitRecDagVoteDiagonalCell(address recipient, uint32 dist, address checkAnscestor) public {
            //     if (readRecDagVoteCount(recipient, dist, dist) == 0) {
            //         return;
            //     }
                
            //     for (uint32 i = readRecDagVoteCount(recipient, dist, dist);  1<=i ; i--) {
            //         DagVote memory rDagVote = readRecDagVote(recipient, dist, dist, i-1);
            //         if (findNthParent(rDagVote.id, dist-1) == checkAnscestor){
            //             safeRemoveRecDagVoteAtDistDepthPos(recipient, dist, dist, i-1);
                        
            //             // this is over the diagonal, but we will push the frame up
            //             combinedDagAppend(rDagVote.id, recipient, dist-1, dist, rDagVote.weight);
            //             sentDagVoteTotalWeight[rDagVote.id] += rDagVote.weight;
            //         }
            //     }
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
                for (uint32 i = 0; i < readRecDagVoteCount(recipient, rdist, depth); i++) {
                    DagVote memory rDagVote = readRecDagVote(recipient, rdist, depth, i);
                    changeDistDepthSent(rDagVote.id, oldRDist+oldDepth, oldDepth, rDagVote.posInOther, recipient, i, rDagVote.weight, rdist-depth, depth);
                    changePositionRec(recipient, rdist, depth, i, readSentDagVoteCount(rDagVote.id, rdist+depth, depth)-1);

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
                for (uint32 i = 1; i <= MAX_REL_ROOT_DEPTH-value; i++) {
                    removeRecDagVoteCell(voter, i, value);
                }
            }

            function removeSentDagVoteLineDistEqualsValue(address voter, uint32 value) internal {
                for (uint32 i = 1; i <= value ; i++) {
                    removeSentDagVoteCell(voter, value, i);
                }
            }


        ///////////// RecDagVotes Diagonal splitter, mergers

            function mergeRecDagVoteDiagonal(address recipient) public {
                // for (uint32 i = 1; i < MAX_REL_ROOT_DEPTH; i++) {
                //     mergeRecDagVoteDiagonalCell(recipient, i);

                // }
                // removeRecDagVoteCell(recipient, MAX_REL_ROOT_DEPTH, MAX_REL_ROOT_DEPTH);
            }

            function splitRecDagVoteDiagonal(address recipient, address checkAnscestor) public {
                // for (uint32 i = 2; i <= MAX_REL_ROOT_DEPTH; i++) {
                //     splitRecDagVoteDiagonalCell(recipient, i, checkAnscestor);
                // }
            }
             

        
    
    ///////////// Area/whole triangle changers
        ///////////// Removers
            function removeSentDagVote(address voter) public {
                for (uint32 i=1; i<=MAX_REL_ROOT_DEPTH; i++){
                    for (uint32 j=1; j<=i; j++){
                        removeSentDagVoteCell(voter, i, j);
                    }
                }
            }

            function removeRecDagVote(address recipient) public {
                for (uint32 i=1; i<=MAX_REL_ROOT_DEPTH; i++){
                    for (uint32 j=1; j<=MAX_REL_ROOT_DEPTH -i; j++){
                        removeRecDagVoteCell(recipient, i, j);
                    }
                }
            }


        ///////////// Collapsing to, and sortging from columns
            function collapseSentDagVoteIntoColumn(address voter, uint32 sdist) public {
                // Todo
            }

            function sortSentDagVoteFromColumn(address voter, uint32 sdist) public {
                // Todo
            }

            function collapseRecDagVoteIntoCulomn( address voter, uint32 rdist) public {
                // todo 
            }

            function sortRecDagVoteFromCulomn( address voter, uint32 rdist) public {
                // todo 
            }
        ///////////// Depth and pos change across graph
            function increaseDistDepthFromSentOnOp(address voter, uint32 sdistDiff, uint32 depthDiff) internal {
                for (uint32 dist = 1; dist <= MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= dist; depth++) {
                        changeDistDepthFromSentCellOnOp(voter, dist, depth, dist-sdistDiff, depth-depthDiff);
                    }
                }
            }

            function decreaseDistDepthFromSentOnOp(address voter, uint32 sdistDiff, uint32 depthDiff) internal {
                for (uint32 dist = 1; dist <= MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= dist; depth++) {
                        changeDistDepthFromSentCellOnOp(voter, dist, depth, dist+sdistDiff, depth+depthDiff);
                    }
                }
            }

            function increaseDistDepthFromRecOnOp(address voter, uint32 rdistDiff, uint32 depthDiff) internal {
                for (uint32 dist = 1; dist <= MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= MAX_REL_ROOT_DEPTH- dist; depth++) {
                        changeDistDepthFromRecCellOnOp(voter, dist, depth, dist-rdistDiff, depth-depthDiff);
                    }
                }
            }

            function decreaseDistDepthFromRecOnOp(address voter, uint32 rdistDiff, uint32 depthDiff) internal {
                for (uint32 dist = 1; dist <= MAX_REL_ROOT_DEPTH; dist++) {
                    for (uint32 depth = 1; depth <= MAX_REL_ROOT_DEPTH- dist; depth++) {
                        changeDistDepthFromRecCellOnOp(voter, dist, depth, dist+rdistDiff, depth+depthDiff);
                    }
                }
            }
        ///////////// Combined dag vote handler for rising falling, 
        
        function handleDagVoteForFalling(address voter, address replacer) internal {

            removeSentDagVoteLineDistEqualsValue(voter, MAX_REL_ROOT_DEPTH);
            decreaseSentDagVoteDepthDiff(voter, 1);
            decreaseSentDagVoteDistDiff(voter, 1);
            // at this point the triangle is in its new position. 
            increaseDistDepthFromSentOnOp(voter, 1, 1);

            splitRecDagVoteDiagonal(voter, replacer);
            removeRecDagVoteLineDepthEqualsValue(voter, 1);
            increaseRecDagVoteDepthDiff(voter, 1);
            decreaseDistDepthFromRecOnOp(voter, 0, 1);
        }

        function handleDagVoteForRising(address voter) internal {
            removeSentDagVoteLineDepthEqualsValue(voter, 1);
            increaseSentDagVoteDepthDiff(voter, 1);
            increaseSentDagVoteDistDiff(voter, 1);
            // at this point the triangle is in its new position. 
            decreaseDistDepthFromSentOnOp(voter, 1, 1);          

            // remove top right triangle
            // merge diagonal parallelogram into column 
            mergeRecDagVoteDiagonal(voter);
            decreaseRecDagVoteDepthDiff(voter, 1);
            increaseDistDepthFromRecOnOp(voter, 0, 1);
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
//// global readers 


    //////////////// reputation

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
//// global internal
    
    function pullUpBranch(address pulledVoter) public {
        // if (readRecTreeVoteCount(pulledVoter)==0) return; 
        // emit SimpleEventForUpdates("pulling up branch for", uint160(pulledVoter));
        address firstChild = readRecTreeVote(pulledVoter, 0);
        address secondChild = readRecTreeVote(pulledVoter, 1);

        if (firstChild!=address(0)){
            
            handleDagVoteForRising(firstChild);
        
            
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
            
            handleDagVoteForRising(firstChild);

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
//// global external

    
    function leaveTree(address voter) public {
        emit SimpleEventForUpdates("hello", 0);
        
        removeSentDagVote(voter);
        removeRecDagVote(voter);

        handleLeavingVoterBranch(voter);
    }


    function switchPositionWithParent(address voter) public {
        emit SimpleEventForUpdates("hello", 0);

        address parent = treeVote[voter];
        assert (parent != address(0));
        assert (parent != address(1));
        
        uint256 voterRep = calculateReputation(voter);
        uint256 parentRep = calculateReputation(parent);

        assert (voterRep > parentRep);
        
        handleDagVoteForFalling(parent, voter);
        handleDagVoteForRising(voter);
        
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
        (bool isHigher, uint32 higherDist, uint32 higherDepth) = findSDistDepth(recipient, relRoot);
        uint32 higherDepthDiff = MAX_REL_ROOT_DEPTH - higherDepth;

        if (isAnscestor){
            // for (uint32 depth=lowerDepth; 0<depth; depth--){
            //     address replacer = findNthParent(recipient, depth-1);
            //     handleDagVoteForFalling(voter, replacer);
            //     handleDagVoteForRising(replacer);
            //     switchTreeVoteWithParent(replacer);
            // }

            // sent removing columns that are too far away 
            // sent falling
            // sent collapsing or sorting not needed, we get further from everyone

            // rec remove rows that are lower than lowerDepth+1
            // rec falling, here we also fall right. 
            // rec no collapse needed, we don't get unequally futher from anyone
            // rec sorting, left coloumns, one for each descendant we fall under, some become closer descendants, some don't. 

        } else if (isLowerOrEqual){
            // sent removing columns that are too high

            // sentDag Array falling

            // collapse bottomleft small triangle into a column
            // sort this column 


            // rec Dag Array higher rows (higher than MRD- jump dist) need to be emptied.
            // rec Dag Arrau lower rows lower than lowerDepth
            // rec Dag Array needs lowering, right and down
            // rec collapse bottom left rectangle (the triangle cap on top has been removed) needs to be collapsed right. 
            // rec sort the column we collapsed into. 

        } else if (isSimilar){
            // here we are automatically not falling, as isLowerOrEqual is false.

            // sentDagVote
            // remove rows with depth under simDepth
            for (uint32 depth =1; depth < simDepth; depth++){
                removeSentDagVoteLineDepthEqualsValue(voter, depth);
            }

            // rising
            increaseSentDagVoteDepthDiff(voter, simDepth-1);
            increaseSentDagVoteDistDiff(voter, simDepth-1);
            decreaseDistDepthFromSentOnOp(voter, simDepth-1, simDepth-1);

            //collapseSentDagVoteIntoColumn(voter, );
            // for each depth cell in the collapsed column
                //sortSentDagVoteFromColumn(voter, ); by specifiyng the depth parent, we can calculate the dist based on that. 

            // recDagVote
            // remove higher rows (higher than MRD-jump dist) need to be emptied.
            for (uint32 depth =MAX_REL_ROOT_DEPTH - simDist; depth <=MAX_REL_ROOT_DEPTH; depth++){
                removeRecDagVoteLineDepthEqualsValue(voter, depth);
            }

            // here we need to collapse the left hand rectangle (cap has been emptied) into a right column first
            // rising,
  
            // now we sort the coloumn we collapsed into, by depth . 

        } else if ((isHigher) && (higherDepthDiff > 1)){

            // remove rows with depth under higherDepthDiff
            for (uint32 depth =1; depth < higherDepthDiff; depth++){
                removeSentDagVoteLineDepthEqualsValue(voter, depth);
            }

           
            
            // because of the rising, we need to change the graph. 
            increaseSentDagVoteDepthDiff(voter, higherDepthDiff-1);
            increaseSentDagVoteDistDiff(voter, higherDepthDiff-1);
            decreaseDistDepthFromSentOnOp(voter, higherDepthDiff-1, higherDepthDiff-1);

            // collapseSentDagVoteIntoColumn(voter, );
            //sorting not required, as we are out of our original tree, so we cannot jump closer. 

            
            // rec dag array needs to be emptied completely.
            removeRecDagVote(voter);
            
        }  else {
            // we jumped out completely, remove all votes. 
            removeSentDagVote(voter);
            removeRecDagVote(voter);            
        }
        // handle tree votes
        handleLeavingVoterBranch(voter);
        addTreeVote(voter, recipient);
    }
}
