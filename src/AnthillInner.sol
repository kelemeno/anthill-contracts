// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


///////////////////////////////////////////
/////////  Structs
    struct DagVote {
        address id;
        uint32 weight;
        // this is for the tables, we can find the sent-received pairs easily. 
        uint32 posInOther;
    }

    struct Dag {
        uint32 decimalPoint;  // total weight of each voter should be 1, but we don't have floats, so we use 10**18.  
        uint32  MAX_REL_ROOT_DEPTH ;
        address  root;

        mapping(address => string)  names;
        mapping(address => address)  treeVote;

        mapping(address => uint32)  recTreeVoteCount;
        mapping(address => mapping(uint32 => address))  recTreeVote;

    

        mapping(address => uint32)  sentDagVoteDistDiff; 
        mapping(address => uint32)  sentDagVoteDepthDiff;
        mapping(address => mapping(uint32 => mapping(uint32 => uint32)))  sentDagVoteCount; // voter -> sdist -> depth -> count
        mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote))))  sentDagVote; // voter -> sdist -> depth -> counter -> DagVote
        
        mapping(address => uint32)  sentDagVoteTotalWeight;
        

        mapping(address => uint32)  recDagVoteDistDiff;
        mapping(address => uint32)  recDagVoteDepthDiff;
        mapping(address => mapping(uint32 => mapping(uint32 => uint32)))  recDagVoteCount; // voter -> rdist -> depth -> count
        mapping(address => mapping(uint32 => mapping(uint32 => mapping(uint32 => DagVote))))  recDagVote; // voter -> rdist -> depth -> counter -> DagVote

        mapping(address => uint256)  reputation;
        mapping(address => bool) repIsCalculated;
   }
///////////////////////////////////////////


library AnthillInner{
    event SimpleEventForUpdates(string str, uint256 randint);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Variable readers 
        // root/base 
            function readRoot(Dag storage dag) public view returns(address){
                return dag.root;
            }

            function readMaxRelRootDepth(Dag storage dag) public view returns(uint32){
                return dag.MAX_REL_ROOT_DEPTH;
            }

        // for node properties
            function readReputation(Dag storage dag, address voter) public view returns(uint256){
                return dag.reputation[voter];
            }

            function readName(Dag storage dag, address voter) public view returns(string memory){
                return dag.names[voter];
            }

        // for tree votes
            function readSentTreeVote(Dag storage dag, address voter) public view returns(address){
                return dag.treeVote[voter];
            }

            function readRecTreeVoteCount(Dag storage dag, address recipient) public view returns(uint32){
                    return dag.recTreeVoteCount[recipient];
            }

            function readRecTreeVote(Dag storage dag, address recipient, uint32 votePos) public view returns(address){
                    return dag.recTreeVote[recipient][votePos];
            }

        // for sent dag 
        
            function readSentDagVoteDistDiff(Dag storage dag, address voter) external view returns(uint32){
                    return dag.sentDagVoteDistDiff[voter];
            }

            function readSentDagVoteDepthDiff(Dag storage dag, address voter) external view returns(uint32){
                    return dag.sentDagVoteDepthDiff[voter];
            }

            function readSentDagVoteCount(Dag storage dag, address voter, uint32 sdist, uint32 depth) public view returns(uint32){
                    return dag.sentDagVoteCount[voter][dag.sentDagVoteDistDiff[voter]+sdist][dag.sentDagVoteDepthDiff[voter]+depth];
            }

            function readSentDagVote(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 votePos) public view returns( DagVote memory){
                    return dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+sdist][dag.sentDagVoteDepthDiff[voter]+depth][votePos];
            }

        
            function readSentDagVoteTotalWeight(Dag storage dag, address voter) public view returns( uint32){
                    return dag.sentDagVoteTotalWeight[voter];
            }
        // for rec Dag votes

            function readRecDagVoteDistDiff(Dag storage dag, address recipient) external view returns(uint32){
                    return dag.recDagVoteDistDiff[recipient];
            }

            function readRecDagVoteDepthDiff(Dag storage dag, address recipient) public view returns(uint32){
                    return dag.recDagVoteDepthDiff[recipient];
            }


            function readRecDagVoteCount(Dag storage dag, address recipient, uint32 rdist, uint32 depth) public view returns(uint32){
                    return dag.recDagVoteCount[recipient][dag.recDagVoteDistDiff[recipient]+rdist][dag.recDagVoteDepthDiff[recipient]+depth];
            }

            function readRecDagVote(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 votePos) public view returns(DagVote memory){
                    return dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+rdist][dag.recDagVoteDepthDiff[recipient]+depth][votePos];
            }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree finder 

        function findRecTreeVotePos(Dag storage dag, address voter, address recipient) public view returns (bool voted, uint32 votePos) {
            for (uint32 i = 0; i < dag.recTreeVoteCount[recipient]; i++) {
                if (dag.recTreeVote[recipient][i] == voter) {
                    return (true, i);
                }
            }
            return (false, 0);
        }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree internal
        function removeTreeVote(Dag storage dag,address voter) public {
            address recipient = dag.treeVote[voter];
            (, uint32 votePos) = findRecTreeVotePos( dag , voter, recipient);

            dag.recTreeVote[recipient][votePos] = dag.recTreeVote[recipient][dag.recTreeVoteCount[recipient]-1];
            dag.recTreeVote[recipient][dag.recTreeVoteCount[recipient]-1]= address(0);
            dag.recTreeVoteCount[recipient] = dag.recTreeVoteCount[recipient] - 1;

            // this sets it to one =1, but removeTreeVote is always temporary, there is always only a single root, and a single voter with dag.treeVote =1 . 
            dag.treeVote[voter] = address(1);
        }
    
        function addTreeVote(Dag storage dag,address voter, address recipient) public {
            assert (dag.treeVote[voter] == address(1));
            assert (dag.recTreeVoteCount[recipient] < 2);

            dag.treeVote[voter] = recipient;

            dag.recTreeVote[recipient][dag.recTreeVoteCount[recipient]] = voter;
            dag.recTreeVoteCount[recipient] = dag.recTreeVoteCount[recipient] + 1;
        }

        function addTreeVoteWithoutCheck(Dag storage dag,address voter, address recipient) public {
            assert (dag.treeVote[voter] == address(1));

            dag.treeVote[voter] = recipient;

            dag.recTreeVote[recipient][dag.recTreeVoteCount[recipient]] = voter;
            dag.recTreeVoteCount[recipient] = dag.recTreeVoteCount[recipient] + 1;
        }

        function switchTreeVoteWithParent(Dag storage dag,address voter) public {
            address parent = dag.treeVote[voter];
            assert (parent != address(0));
            assert (parent != address(1));
            
            address gparent = dag.treeVote[parent]; // this can be 1. 

            removeTreeVote( dag , voter);
            
            if (readRoot( dag  )== parent){
                dag.root = voter;
            } else {
                removeTreeVote( dag , parent);
            }

            address brother = dag.recTreeVote[parent][0];

            address child1 = dag.recTreeVote[voter][0];
            address child2 = dag.recTreeVote[voter][1];
            
            addTreeVoteWithoutCheck( dag , voter, gparent);
            addTreeVoteWithoutCheck( dag , parent, voter);

            if (brother != address(0)) {
                removeTreeVote(dag, brother);
                addTreeVoteWithoutCheck( dag , brother, voter);
            }

            if (child1 != address(0)) {
                removeTreeVote(dag, child1);
                addTreeVoteWithoutCheck( dag , child1, parent);
            }

            if (child2 != address(0)) {
                removeTreeVote(dag, child2);
                addTreeVoteWithoutCheck( dag , child2, parent);
            }
       }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Local tree finders
        
        function findNthParent(Dag storage dag,address voter, uint32 height) public view returns (address parent){
            if (height == 0) {
                return voter;
            }

            if (dag.treeVote[voter] == address(1)) {
                return address(1);
            }

            // this should never be the case, but it is a safety check
            assert (dag.treeVote[voter] != address(0));

            return findNthParent( dag , dag.treeVote[voter], height-1);
        }

        // to find our relative dag.root, our ancestor at depth dag.MAX_REL_ROOT_DEPTH
        function findRelRoot(Dag storage dag, address voter) public view returns (address relRoot, uint32 relDepth){
            assert (dag.treeVote[voter] != address(0));

            relRoot = voter;
            address parent;

            for (relDepth = 0; relDepth < dag.MAX_REL_ROOT_DEPTH; relDepth++) {
                parent = dag.treeVote[relRoot];
                if (parent == address(1)) {
                    break;
                }
                relRoot = parent;
            }
            return (relRoot, relDepth);
        }

        // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative dag.root
        function findRelDepth(Dag storage dag,address voter, address recipient) public view returns (bool isLocal, uint32 relDepth){
            
            if ((dag.treeVote[voter] == address(0)) || (dag.treeVote[recipient] == address(0))) {
                return (false, 0);
            }

            (address relRoot, uint32 relRootDiff) = findRelRoot( dag , voter);
            address recipientAncestor = recipient;

            for (uint32 i = 0; i <= relRootDiff; i++) {
                if (recipientAncestor == relRoot) {
                    return (true, relRootDiff-i);
                }
                
                recipientAncestor = dag.treeVote[recipientAncestor];

                if (recipientAncestor == address(0)) {
                    return (false, 0);
                }
            }
            return (false, 0);
        }

        // to find the distance between voter and recipient, within maxDistance. 
        // THIS IS ACTUALLY A GLOBAL FUNTION!
        function findDistAtSameDepth(Dag storage dag,address add1, address add2) public view returns (bool isSameDepth, uint32 distance) {
            if (add1 == add2){
                return (true, 0);
            }
            
            if ( dag.treeVote[add1] == address(0) || dag.treeVote[add2] == address(0)) {
                return (false, 0);
            }        

            if (dag.treeVote[add1] == address(1) || dag.treeVote[add2] == address(1)) {
                return (false, 0);
            }

            (isSameDepth, distance) = findDistAtSameDepth( dag , dag.treeVote[add1], dag.treeVote[add2]);

            if (isSameDepth == true) {
                return (true, distance + 1);
            }

            return (false, 0);
        }

        // 
        function findSDistDepth(Dag storage dag,address voter, address recipient) public view returns (bool isLocal, uint32 distance, uint32 relDepth){
            if (dag.treeVote[voter] == address(0) || dag.treeVote[recipient] == address(0)) {
                return (false, 0, 0);
            }

            (isLocal,  relDepth) = findRelDepth( dag , voter, recipient);
            if (isLocal == false) {
                return (false, 0, 0);
            }

            address voterAnscenstor = findNthParent( dag , voter, relDepth);

            (,  distance)= findDistAtSameDepth( dag , voterAnscenstor, recipient);

            return (isLocal, distance+relDepth, relDepth);
        }

        

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// DAG finders
        // to check the existence and to find the position of a vote in a given row of the sentDagVote array
        function findSentDagVotePosAtDistDepth(Dag storage dag,address voter, address recipient, uint32 sdist,  uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            for (uint32 i = 0; i < readSentDagVoteCount( dag , voter, sdist, depth) ; i++) {
                DagVote memory sDagVote = readSentDagVote( dag , voter, sdist, depth, i);
                if (sDagVote.id == recipient) {
                    return (true, i, sDagVote);
                }
            }

            return (false, 0, DagVote(address(0), 0, 0));
        }

        // to check the existence and to find the position of a vote in a given row of the recDagVote array
        function findRecDagVotePosAtDistDepth(Dag storage dag,address voter, address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
                for (uint32 i = 0; i < readRecDagVoteCount( dag , recipient, rdist, depth) ; i++) {
                    DagVote memory rDagVote = readRecDagVote( dag , recipient, rdist, depth, i);
                    if (rDagVote.id == voter) {
                        return (true, i, rDagVote);
                    }
                }

                return (false, 0, DagVote(address(0), 0, 0));
        }

        function findLastSentDagVoteAtDistDepth(Dag storage dag,address voter, uint32 sdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            
            uint32 count = readSentDagVoteCount( dag , voter, sdist, depth);

            if (count == 0) {
                return (false, 0, DagVote(address(0), 0, 0));
            }

            return (true, count-1, readSentDagVote( dag , voter, sdist ,depth, count-1));
        }

        function findLastRecDagVoteAtDistDepth(Dag storage dag,address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
        
            uint32 count = readRecDagVoteCount( dag , recipient, rdist, depth);

            if (count == 0) {
                return (false, 0, DagVote(address(0), 0, 0));
            }

            return (true, count-1, readRecDagVote( dag , recipient, rdist,  depth, count-1));
        }

        // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
        function findSentDagVote(Dag storage dag,address voter, address recipient) public view returns (bool votable, bool voted, uint32 sdist,  uint32 depth, uint32 votePos, DagVote memory dagVote){ 
            bool isLocal;
            (isLocal,  sdist,  depth) = findSDistDepth( dag , voter, recipient);
            
            if ((isLocal == false) || (depth == 0)) {
                return (false, false, 0, 0, 0,  DagVote(address(0), 0, 0));
            }

            (voted,  votePos, dagVote) = findSentDagVotePosAtDistDepth( dag , voter, recipient, sdist, depth);

            return (true, voted, sdist, depth, votePos, dagVote);
        }

        // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
        function findRecDagVote(Dag storage dag,address voter, address recipient) public view returns (bool votable, bool voted, uint32 rdist, uint32 depth, uint32 votePos, DagVote memory dagVote){
                bool isLocal;
                uint32 sdist;

                ( isLocal, sdist, depth) = findSDistDepth( dag , voter, recipient);
                rdist= sdist - depth;

                if ((isLocal == false) || (depth == 0)) {
                    return (false, false, 0, 0, 0,  DagVote(address(0), 0, 0));
                }

                (voted, votePos, dagVote) = findRecDagVotePosAtDistDepth( dag , voter, recipient, rdist, depth);

                return (true, voted, rdist,  depth, votePos, dagVote);
        }



    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag internals. Core logic. 
        ///////////// Setters      
            ///////////// Diffs
                function increaseSentDagVoteDistDiff(Dag storage dag, address voter, uint32 diff) public{
                    dag.sentDagVoteDistDiff[voter] += diff;
                }

                function decreaseSentDagVoteDistDiff(Dag storage dag, address voter, uint32 diff) public{
                    dag.sentDagVoteDistDiff[voter] -= diff;
                }

                function increaseRecDagVoteDistDiff(Dag storage dag, address recipient, uint32 diff) public{
                    dag.recDagVoteDistDiff[recipient] += diff;
                }

                function decreaseRecDagVoteDistDiff(Dag storage dag, address recipient, uint32 diff) public{
                    dag.recDagVoteDistDiff[recipient] -= diff;
                }

                function increaseSentDagVoteDepthDiff(Dag storage dag, address voter, uint32 diff) public{
                    dag.sentDagVoteDepthDiff[voter] += diff;
                }

                function decreaseSentDagVoteDepthDiff(Dag storage dag, address voter, uint32 diff) public{
                    dag.sentDagVoteDepthDiff[voter] -= diff;
                }

                function increaseRecDagVoteDepthDiff(Dag storage dag, address recipient, uint32 diff) public{
                    dag.recDagVoteDepthDiff[recipient] += diff;
                }

                function decreaseRecDagVoteDepthDiff(Dag storage dag, address recipient,  uint32 diff) public{
                    dag.recDagVoteDepthDiff[recipient] -= diff;
                }

            ///////////// Counts 

                function increaseSentDagVoteCount(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 diff) public{
                    dag.sentDagVoteCount[voter][dag.sentDagVoteDistDiff[voter]+sdist][dag.sentDagVoteDepthDiff[voter]+depth] += diff;
                }

                function decreaseSentDagVoteCount(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 diff) public{
                    dag.sentDagVoteCount[voter][dag.sentDagVoteDistDiff[voter]+sdist][dag.sentDagVoteDepthDiff[voter]+depth] -= diff;
                }

                function increaseRecDagVoteCount(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 diff) public{
                    dag.recDagVoteCount[recipient][dag.recDagVoteDistDiff[recipient]+rdist][dag.recDagVoteDepthDiff[recipient]+depth] += diff;
                }

                function decreaseRecDagVoteCount(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 diff) public{
                    dag.recDagVoteCount[recipient][dag.recDagVoteDistDiff[recipient]+rdist][dag.recDagVoteDepthDiff[recipient]+depth] -= diff;
                }

            ///////////// Votes

                function setSentDagVote(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 sPos, address recipient, uint32 weight, uint32 rPos) public{
                    dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+sdist][dag.sentDagVoteDepthDiff[voter]+depth][sPos] = DagVote({id: recipient, weight: weight, posInOther: rPos});
                }

                function setRecDagVote(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 rPos, address voter, uint32 weight, uint32 sPos) public{
                    dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+rdist][dag.recDagVoteDepthDiff[recipient]+depth][rPos] = DagVote({id: voter, weight: weight, posInOther: sPos});
                }

        ///////////// Single vote changes
            ///////////// appending a vote

                function sentDagAppend(Dag storage dag, address voter, uint32 sdist, uint32 depth, address recipient, uint32 weight, uint32 rPos ) public{
                    setSentDagVote( dag ,  voter, sdist, depth, readSentDagVoteCount( dag , voter, sdist , depth), recipient, weight, rPos); 
                    increaseSentDagVoteCount( dag , voter, sdist, depth, 1);
                }

                function recDagAppend(Dag storage dag, address recipient, uint32 rdist, uint32 depth, address voter, uint32 weight, uint32 sPos ) public{
                    setRecDagVote( dag , recipient, rdist, depth, readRecDagVoteCount( dag , recipient, rdist , depth), voter, weight, sPos);
                    increaseRecDagVoteCount( dag , recipient, rdist, depth, 1);
                }

                function combinedDagAppendSdist(Dag storage dag, address voter, address recipient,  uint32 sdist, uint32 depth, uint32 weight) public{
                    sentDagAppend( dag , voter, sdist, depth, recipient, weight, readRecDagVoteCount( dag , recipient, sdist-depth, depth));
                    dag.sentDagVoteTotalWeight[voter] += weight;
                    recDagAppend( dag , recipient, sdist-depth, depth, voter, weight,  readSentDagVoteCount( dag , voter, sdist, depth)-1);
                }

            ///////////// changing position

                function changePositionSent(Dag storage dag, address voter, uint32 sdist,  uint32 depth, uint32 sPos, uint32 newRPos) public {
                    dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+ sdist][dag.sentDagVoteDepthDiff[voter]+depth][sPos].posInOther = newRPos;
                }

                function changePositionRec(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newSPos) public{
                    dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+ rdist][dag.recDagVoteDepthDiff[recipient]+depth][rPos].posInOther = newSPos;
                }   

            

            ///////////// delete and removal functions
                ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.
                
                /// careful, does not delete the opposite or deacrese count! Do not call, call unsafeReplace..  or safeRemove.. instead
                function unsafeDeleteLastSentDagVoteAtDistDepth(Dag storage dag, address voter, uint32 sdist, uint32 depth) public {
                    delete dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+ sdist][dag.sentDagVoteDepthDiff[voter]+depth][readSentDagVoteCount(dag, voter, sdist, depth)-1];
                }

                /// careful, does not delete the opposite, or decrease count! Do not call, call unsafeReplace..  or safeRemove.. instead
                function unsafeDeleteLastRecDagVoteAtDistDepth(Dag storage dag, address recipient, uint32 rdist, uint32 depth) public {
                    delete dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+ rdist][dag.recDagVoteDepthDiff[recipient]+depth][readRecDagVoteCount(dag, recipient, rdist, depth)-1];
                }   

                // careful does not delete the opposite! Always call with opposite, or do something with the other vote
                function unsafeReplaceSentDagVoteAtDistDepthPosWithLast(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 sPos) public {
                    // find the vote we delete
                    DagVote memory sDagVote = readSentDagVote( dag , voter, sdist, depth, sPos);      
                    dag.sentDagVoteTotalWeight[voter] -= sDagVote.weight;

                    if (sPos!= readSentDagVoteCount( dag , voter, sdist, depth)-1) {
                        // if we delete a vote in the middle, we need to copy the last vote to the deleted position
                        (,, DagVote memory copiedSentDagVote) = findLastSentDagVoteAtDistDepth( dag , voter, sdist, depth);
                        setSentDagVote( dag , voter, sdist, depth, sPos, copiedSentDagVote.id, copiedSentDagVote.weight, copiedSentDagVote.posInOther);
                        changePositionRec( dag , copiedSentDagVote.id , sdist-depth, depth, copiedSentDagVote.posInOther, sPos);
                    }
                    
                    // delete the potentially copied hence duplicate last vote
                    unsafeDeleteLastSentDagVoteAtDistDepth( dag , voter, sdist, depth);
                    decreaseSentDagVoteCount( dag , voter, sdist, depth, 1);
                } 

                /// careful, does not delete the opposite!
                function unsafeReplaceRecDagVoteAtDistDepthPosWithLast(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 rPos) public {
                    if (rPos != readRecDagVoteCount( dag , recipient, rdist, depth)-1) {
                        (,, DagVote memory copiedRecDagVote) = findLastRecDagVoteAtDistDepth( dag , recipient, rdist, depth);
                        setRecDagVote( dag , recipient, rdist, depth, rPos, copiedRecDagVote.id, copiedRecDagVote.weight, copiedRecDagVote.posInOther);
                        changePositionSent( dag , copiedRecDagVote.id , rdist+depth, depth, copiedRecDagVote.posInOther, rPos); 
                    }

                    // delete the the potentially copied hence duplicate last vote
                    unsafeDeleteLastRecDagVoteAtDistDepth( dag , recipient, rdist, depth);
                    decreaseRecDagVoteCount( dag , recipient, rdist, depth, 1);
                } 

                function safeRemoveSentDagVoteAtDistDepthPos(Dag storage dag,address voter, uint32 sdist, uint32 depth, uint32 sPos) public {
                    DagVote memory sDagVote = readSentDagVote( dag , voter,sdist, depth, sPos);
                    unsafeReplaceSentDagVoteAtDistDepthPosWithLast( dag , voter, sdist, depth, sPos);
                    // delete the opposite
                    unsafeReplaceRecDagVoteAtDistDepthPosWithLast( dag , sDagVote.id, sdist-depth, depth, sDagVote.posInOther);
                }

                function safeRemoveRecDagVoteAtDistDepthPos(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 rPos) public {
                    DagVote memory rDagVote = readRecDagVote( dag , recipient, rdist, depth, rPos);
                    unsafeReplaceRecDagVoteAtDistDepthPosWithLast( dag , recipient, rdist, depth, rPos);
                    // delete the opposite
                    unsafeReplaceSentDagVoteAtDistDepthPosWithLast( dag , rDagVote.id, rdist+depth, depth, rDagVote.posInOther);
                }

            ///////////// change dist and depth
                function changeDistDepthSent(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 sPos, uint32 newSDist, uint32 newDepth, address recipient, uint32 rPos, uint32 weight) public{
                    // here it is ok to use unsafe, as the the vote is moved, not removed
                    unsafeReplaceSentDagVoteAtDistDepthPosWithLast( dag , voter, sdist, depth, sPos);                
                    sentDagAppend( dag , voter, newSDist, newDepth, recipient, weight, rPos);
                    dag.sentDagVoteTotalWeight[voter] += weight;
                }

                function changeDistDepthRec(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newRDist, uint32 newDepth, address voter, uint32 sPos, uint32 weight) public{
                    // here it is ok to use unsafe, as the the vote is moved, not removed
                    unsafeReplaceRecDagVoteAtDistDepthPosWithLast( dag , recipient, rdist, depth, rPos);                
                    recDagAppend( dag , recipient, newRDist, newDepth, voter, weight, sPos);
                }

        ///////////// Cell removal and handler functions 
            ///////////// removal 
                // to remove a row of votes from the dag.sentDagVote array, and the corresponding votes from the dag.recDagVote arrays
                function removeSentDagVoteCell(Dag storage dag, address voter, uint32 sdist, uint32 depth) public {
                    if (readSentDagVoteCount(dag, voter, sdist, depth) == 0) {
                        return;
                    }
                    for (uint32 i = readSentDagVoteCount(dag, voter, sdist, depth); 1 <= i; i--) {
                        safeRemoveSentDagVoteAtDistDepthPos(dag, voter, sdist, depth, i-1);
                    }
                }

                // to remove a row of votes from the dag.recDagVote array, and the corresponding votes from the dag.sentDagVote arrays
                function removeRecDagVoteCell(Dag storage dag, address recipient, uint32 rdist, uint32 depth) public {
                    if (readRecDagVoteCount(dag, recipient, rdist, depth) == 0) {
                        return;
                    }
                    for (uint32 i =  readRecDagVoteCount(dag, recipient, rdist, depth); 1 <= i; i--){
                        safeRemoveRecDagVoteAtDistDepthPos(dag, recipient, rdist, depth, i-1);
                    }
                }

            
            
            ///////////// dist depth on opposite 
                function changeDistDepthFromSentCellOnOp(Dag storage dag, address voter, uint32 sdist, uint32 depth, uint32 oldSDist, uint32 oldDepth) public {
                    for (uint32 i = 0; i < readSentDagVoteCount(dag, voter, sdist, depth); i++) {
                        DagVote memory sDagVote = readSentDagVote(dag, voter, sdist, depth, i);
                 
                        changeDistDepthRec(dag, sDagVote.id, oldSDist-oldDepth, oldDepth, sDagVote.posInOther, sdist-depth, depth, voter, i, sDagVote.weight);
                        changePositionSent(dag, voter, sdist, depth, i, readRecDagVoteCount(dag, sDagVote.id, sdist-depth, depth)-1);
                    }
                }

                function changeDistDepthFromRecCellOnOp(Dag storage dag, address recipient, uint32 rdist, uint32 depth, uint32 oldRDist, uint32 oldDepth) public {
                    for (uint32 i = 0; i <  readRecDagVoteCount(dag, recipient, rdist, depth); i++) {
                        
                        
                        DagVote memory rDagVote = readRecDagVote( dag , recipient, rdist, depth, i);
                        changeDistDepthSent( dag , rDagVote.id, oldRDist+oldDepth, oldDepth, rDagVote.posInOther, rdist+depth, depth, recipient, i, rDagVote.weight);
                        changePositionRec( dag , recipient, rdist, depth, i, readSentDagVoteCount( dag , rDagVote.id, rdist+depth, depth)-1);
                    }
                }
            
            ///////////// move cell

                function moveSentDagVoteCell(Dag storage dag,address voter, uint32 sdist, uint32 depth, uint32 newSDist, uint32 newDepth) public {
                    for (uint32 i = readSentDagVoteCount( dag , voter, sdist, depth); 0 < i; i--) {
                        DagVote memory sDagVote = readSentDagVote( dag , voter, sdist, depth, i-1);
                        safeRemoveSentDagVoteAtDistDepthPos( dag , voter, sdist, depth, i-1);
                        combinedDagAppendSdist( dag , voter, sDagVote.id, newSDist, newDepth, sDagVote.weight);
                    }
                }

                function moveRecDagVoteCell(Dag storage dag,address recipient, uint32 rdist, uint32 depth, uint32 newRDist, uint32 newDepth) public {
                    for (uint32 i = readRecDagVoteCount( dag , recipient, rdist, depth); 0 < i; i--) {
                        DagVote memory rDagVote = readRecDagVote( dag , recipient, rdist, depth, i-1);
                        safeRemoveRecDagVoteAtDistDepthPos( dag , recipient, rdist, depth, i-1);
                        combinedDagAppendSdist( dag , rDagVote.id, recipient,  newRDist+newDepth, newDepth, rDagVote.weight);
                    }
                }

        ///////////// Line  remover and sorter functions
            ///////////// Line removers

                function removeSentDagVoteLineDepthEqualsValue(Dag storage dag, address voter, uint32 value) public {
                    for (uint32 dist = value; dist <= dag.MAX_REL_ROOT_DEPTH ; dist++) {
                        removeSentDagVoteCell( dag , voter, dist, value);
                    }
                }

                function removeRecDagVoteLineDepthEqualsValue(Dag storage dag, address voter, uint32 value) public {
                    for (uint32 dist = 0; dist <= dag.MAX_REL_ROOT_DEPTH-value; dist++) {
                        removeRecDagVoteCell( dag , voter, dist, value);
                    }
                }

                function removeSentDagVoteLineDistEqualsValue(Dag storage dag, address voter, uint32 value) public {
                    for (uint32 depth = 1; depth <= value ; depth++) {
                        removeSentDagVoteCell( dag , voter, value, depth);
                    }
                }


            ///////////// Sort Cell into line
                function sortSentDagVoteCell(Dag storage dag, address voter, uint32 sdist, uint32 depth, address anscestorAtDepth) public {
                    for (uint32 i = readSentDagVoteCount( dag , voter, sdist, depth); 0 < i ; i--) {
                        DagVote memory sDagVote = readSentDagVote( dag , voter, sdist, depth, i-1);

                        (, uint32 distFromAnsc)= findDistAtSameDepth( dag , sDagVote.id, anscestorAtDepth);
                        if (sdist != distFromAnsc + depth) {
                            safeRemoveSentDagVoteAtDistDepthPos( dag , voter, sdist, depth, i-1);
                            combinedDagAppendSdist( dag , voter, sDagVote.id, distFromAnsc + depth, depth, sDagVote.weight);
                        } 
                    }
                }

                function sortRecDagVoteCell(Dag storage dag, address recipient, uint32 rdist, uint32 depth,  address newTreeVote) public {
                    for (uint32 i = readRecDagVoteCount( dag , recipient, rdist, depth); 0 < i; i--) {
                        DagVote memory rDagVote = readRecDagVote( dag , recipient, rdist, depth, i-1);

                        address anscestorOfSenderAtDepth = findNthParent( dag , rDagVote.id, depth+1);
                        (bool  sameHeight, uint32 distFromNewTreeVote)= findDistAtSameDepth( dag , newTreeVote, anscestorOfSenderAtDepth);
                        assert (sameHeight); // sanity check 

                        safeRemoveRecDagVoteAtDistDepthPos( dag , recipient, rdist, depth, i-1);
                        combinedDagAppendSdist( dag , rDagVote.id, recipient, distFromNewTreeVote +depth+1, depth, rDagVote.weight);
                    }
                }

                function sortRecDagVoteCellDescendants(Dag storage dag, address recipient, uint32 depth, address replaced) public {
                    for (uint32 i = readRecDagVoteCount( dag , recipient, 1, depth); 0 < i; i--) {
                        DagVote memory rDagVote = readRecDagVote( dag , recipient, 1, depth, i - 1);

                        address anscestorAtDepth = findNthParent( dag , rDagVote.id, depth);

                        if (anscestorAtDepth == replaced) {
                            safeRemoveRecDagVoteAtDistDepthPos( dag , recipient, 1, depth, i-1);
                            combinedDagAppendSdist( dag , rDagVote.id, recipient, depth, depth, rDagVote.weight);
                        }
                    }
                }
        
        ///////////// Area/whole triangle changers
            ///////////// Removers
                //////////// complete triangles
                    function removeSentDagVoteComplete(Dag storage dag, address voter) public {
                        for (uint32 depth = 1; depth <=dag.MAX_REL_ROOT_DEPTH; depth ++){
                            removeSentDagVoteLineDepthEqualsValue( dag , voter, depth);
                        }
                    }

                    function removeRecDagVoteComplete(Dag storage dag, address recipient) public {
                        for (uint32 depth = 1; depth <= dag.MAX_REL_ROOT_DEPTH; depth++){
                            removeRecDagVoteLineDepthEqualsValue( dag , recipient, depth);
                        }
                    }

                //////////// function removeRecDagVote above/below a line

                    function removeSentDagVoteAboveHeightInclusive(Dag storage dag, address voter, uint32 depth) public {
                        for (uint32 depthIter=depth; depthIter <= dag.MAX_REL_ROOT_DEPTH ; depthIter++){
                            removeSentDagVoteLineDepthEqualsValue( dag , voter, depthIter);
                        }
                        
                    }

                    function removeSentDagVoteBelowHeightInclusive(Dag storage dag, address voter, uint32 depth) public {
                        for (uint32 depthIter=1; depthIter<=depth; depthIter++){
                            removeSentDagVoteLineDepthEqualsValue( dag , voter, depthIter);
                        }
                    }

                    function removeSentDagVoteFurtherThanDistInclusive(Dag storage dag, address voter, uint32 dist) public {
                        for (uint32 distIter=dist ; distIter<=dag.MAX_REL_ROOT_DEPTH; distIter++){
                            removeSentDagVoteLineDistEqualsValue( dag , voter, distIter);
                        }
                    }

                    function removeRecDagVoteAboveDepthInclusive(Dag storage dag, address voter, uint32 depth) public {
                        for (uint32 depthIter=1; depthIter<=depth; depthIter++){
                            removeRecDagVoteLineDepthEqualsValue(dag, voter, depthIter);
                        }
                        
                    }

                    function removeRecDagVoteBelowDepthInclusive(Dag storage dag, address voter, uint32 depth) public {
                        for (uint32 depthIter=depth; depthIter<= dag.MAX_REL_ROOT_DEPTH; depthIter++){
                            removeRecDagVoteLineDepthEqualsValue( dag , voter, depthIter);
                        }
                    }

                    


            
            ///////////// Depth and pos change across graph
                function increaseDistDepthFromSentOnOpFalling(Dag storage dag, address voter, uint32 diff) public {
                    // here we start from diff, as we pushed the triangle up right, so bottom rows are empty. 
                    for (uint32 dist = diff; dist <= dag.MAX_REL_ROOT_DEPTH; dist++) {
                        for (uint32 depth = diff; depth <= dist; depth++) {
                            changeDistDepthFromSentCellOnOp(dag, voter, dist, depth, dist-diff, depth-diff);
                        }
                    }
                }

                function decreaseDistDepthFromSentOnOpRising(Dag storage dag, address voter, uint32 diff) public {
                    for (uint32 dist = 1; dist <= dag.MAX_REL_ROOT_DEPTH; dist++) {
                        for (uint32 depth = 1; depth <= dist; depth++) {
                            changeDistDepthFromSentCellOnOp(dag, voter, dist, depth, dist+diff, depth+diff);
                        }
                    }
                }

                function changeDistDepthFromRecOnOpFalling(Dag storage dag, address voter, uint32 diff) public {
                    // we start from diff, as we collapsed already
                    for (uint32 dist = diff; dist < dag.MAX_REL_ROOT_DEPTH; dist++) {
                        for (uint32 depth = 1; depth <= dag.MAX_REL_ROOT_DEPTH- dist; depth++) {
                            changeDistDepthFromRecCellOnOp(dag, voter, dist, depth, dist-diff, depth+diff);
                        }
                    }
                }

                function changeDistDepthFromRecOnOpRising(Dag storage dag, address voter, uint32 diff) public {
                    // depth starts from diff, we should have emtied the lower depths already. 
                    for (uint32 dist = 0; dist < dag.MAX_REL_ROOT_DEPTH; dist++) {
                        for (uint32 depth = diff; depth <= dag.MAX_REL_ROOT_DEPTH- dist; depth++) {
                            changeDistDepthFromRecCellOnOp(dag, voter, dist, depth, dist+diff, depth-diff);
                        }
                    }
                }

            ///////////// Movers
                function moveSentDagVoteUpRightFalling(Dag storage dag, address voter, uint32 diff) public {
                    decreaseSentDagVoteDepthDiff(dag, voter, diff);
                    decreaseSentDagVoteDistDiff(dag, voter, diff);
                    increaseDistDepthFromSentOnOpFalling(dag, voter, diff);
                }

                function moveSentDagVoteDownLeftRising(Dag storage dag, address voter, uint32 diff) public {
                    increaseSentDagVoteDepthDiff(dag, voter, diff);
                    increaseSentDagVoteDistDiff(dag, voter, diff);
                    decreaseDistDepthFromSentOnOpRising(dag, voter,  diff);
                }

                function moveRecDagVoteUpRightFalling(Dag storage dag, address voter, uint32 diff) public {
                    decreaseRecDagVoteDistDiff(dag, voter, diff);
                    increaseRecDagVoteDepthDiff(dag, voter, diff);
                    changeDistDepthFromRecOnOpFalling(dag, voter, diff);
                }

                function moveRecDagVoteDownLeftRising(Dag storage dag, address voter, uint32 diff) public {
                    increaseRecDagVoteDistDiff(dag, voter, diff);
                    decreaseRecDagVoteDepthDiff(dag, voter, diff);
                    changeDistDepthFromRecOnOpRising(dag, voter, diff);
                }
            ///////////// Collapsing to, and sorting from columns

                function collapseSentDagVoteIntoColumn(Dag storage dag, address voter, uint32 sdistDestination) public {
                    for (uint32 sdist = 1; sdist < sdistDestination; sdist++) {
                        for (uint32 depth = 1; depth <= sdist; depth++){ 
                            moveSentDagVoteCell(dag, voter, sdist, depth, sdistDestination, depth);
                        }
                    }
                }            

                function collapseRecDagVoteIntoColumn(Dag storage dag,  address voter, uint32 rdistDestination) public {
                    for (uint32 rdist = 0; rdist <  rdistDestination; rdist++) {
                        for (uint32 depth = 1; depth <=dag.MAX_REL_ROOT_DEPTH- rdist; depth++){ 
                            if (depth <= dag.MAX_REL_ROOT_DEPTH - rdistDestination){
                                moveRecDagVoteCell(dag, voter, rdist, depth, rdistDestination, depth);
                            } else {
                                removeRecDagVoteCell(dag, voter, rdist, depth);
                            }
                        }
                    }
                }

                function sortSentDagVoteColumn(Dag storage dag, address voter, uint32 sdist, address newTreeVote) public {
                    address anscestorAtDepth = newTreeVote;
                    for (uint32 depth = 1; depth <= sdist; depth++) {
                        sortSentDagVoteCell(dag, voter, sdist, depth, anscestorAtDepth);
                        anscestorAtDepth = dag.treeVote[anscestorAtDepth];
                    }
                }

                function sortRecDagVoteColumn( Dag storage dag, address recipient, uint32 rdist, address newTreeVote) public {
                    for (uint32 depth = 1; depth <= dag.MAX_REL_ROOT_DEPTH-rdist; depth++) {
                        sortRecDagVoteCell(dag, recipient, rdist, depth,  newTreeVote);                    
                    }
                }

                function sortRecDagVoteColumnDescendants(Dag storage dag,  address recipient, address replaced) public {
                    // here dist is 1, as we are sorting the descendant from our brother's desdcendant 
                    for (uint32 depth = 1; depth <= dag.MAX_REL_ROOT_DEPTH-1; depth++) {
                        sortRecDagVoteCellDescendants(dag, recipient, depth, replaced);
                    } 
                }

            ///////////// Combined dag Square vote handler for rising falling, a certain depth, with passing the new recipient in for selction    

                function handleDagVoteMoveRise(Dag storage dag, address voter, address recipient, address replaced, uint32 moveDist, uint32 depthToRec ) public {
                    // sent 
                    removeSentDagVoteBelowHeightInclusive(dag, voter, depthToRec - 1);
                    collapseSentDagVoteIntoColumn(dag, voter, moveDist);
                    moveSentDagVoteDownLeftRising(dag, voter, depthToRec - 1);
                    sortSentDagVoteColumn(dag, voter, moveDist - depthToRec + 1, recipient);  

                    // rec
                    removeRecDagVoteBelowDepthInclusive(dag, voter, dag.MAX_REL_ROOT_DEPTH - moveDist + 1);         
                    collapseRecDagVoteIntoColumn(dag, voter, moveDist);
                    moveRecDagVoteDownLeftRising(dag, voter, depthToRec-1);            
                    sortRecDagVoteColumn(dag, voter, moveDist-depthToRec+1,  recipient);
                    
                    if (replaced != address(0)) {
                        sortRecDagVoteColumnDescendants(dag, voter, replaced);
                    } 
                }

                function handleDagVoteMoveFall(Dag storage dag, address voter, address recipient, address replaced, uint32 moveDist, uint32 depthToRec) public {
                    // sent 
                    removeSentDagVoteFurtherThanDistInclusive( dag , voter, dag.MAX_REL_ROOT_DEPTH + 1 - depthToRec - 1);
                    collapseSentDagVoteIntoColumn( dag , voter, moveDist);
                    moveSentDagVoteUpRightFalling( dag , voter, depthToRec + 1);
                    sortSentDagVoteColumn( dag , voter, moveDist + depthToRec +1 , recipient);  

                    // rec
                    removeRecDagVoteAboveDepthInclusive( dag , voter, depthToRec +1);         
                    removeRecDagVoteBelowDepthInclusive( dag , voter, dag.MAX_REL_ROOT_DEPTH - moveDist + 1);
                    collapseRecDagVoteIntoColumn( dag , voter, moveDist);
                    moveRecDagVoteUpRightFalling( dag , voter, depthToRec + 1 );            
                    sortRecDagVoteColumn( dag , voter, moveDist + depthToRec + 1 , recipient);
                    
                    if (replaced != address(0)) {
                        sortRecDagVoteColumnDescendants( dag , voter, replaced);
                    } 
                }



    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global internal
        
        function pullUpBranch(Dag storage dag,address pulledVoter, address parent) public {
            // we fist handle the dag structure, using the tree structure, then we change the tree votes. 
            
            // if (readRecTreeVoteCount(pulledVoter)==0) return; 
            // emit SimpleEventForUpdates("pulling up branch for", uint160(pulledVoter));
            address firstChild = readRecTreeVote( dag , pulledVoter, 0);
            address secondChild = readRecTreeVote( dag , pulledVoter, 1);

            if (firstChild!=address(0)){
                
                handleDagVoteMoveRise( dag , firstChild, parent, pulledVoter, 2, 2);
            
                pullUpBranch( dag , firstChild, pulledVoter);    

                if (secondChild != address(0)){
                    removeTreeVote( dag , secondChild);
                    addTreeVote( dag , secondChild, firstChild);
                }
            }

        }
        
        function handleLeavingVoterBranch(Dag storage dag, address voter) public {
            // we fist handle the dag structure, using the tree structure, then we change the tree votes. 

            address parent = dag.treeVote[voter];

            address firstChild = readRecTreeVote( dag , voter, 0);
            address secondChild = readRecTreeVote( dag , voter, 1);

            if (firstChild!=address(0)){
                
                handleDagVoteMoveRise( dag , firstChild, parent, voter, 2, 2);

                pullUpBranch( dag , firstChild, voter);

                if (secondChild != address(0)){
                    removeTreeVote( dag , secondChild);
                    addTreeVote( dag , secondChild, firstChild);
                }

                removeTreeVote( dag , firstChild);
                addTreeVoteWithoutCheck( dag , firstChild, parent);
            }

            removeTreeVote( dag , voter);
            dag.treeVote[voter]=address(1);

            if (dag.root == voter ){
                dag.root = firstChild;
            }
        } 
}