// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import {Dag,  DagVote, AnthillInner} from "./AnthillInner.sol";

contract Anthill {


    constructor() {
        dag.decimalPoint = 18;
        dag.MAX_REL_ROOT_DEPTH = 6;

    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// State variables   
        using AnthillInner for Dag; 
        Dag public dag; 
        bool public unlocked = true;

        string public tokenName = "Anthill";
        string public tokenSymbol = "ANTH";

        function decimals() public view returns(uint256) {
            return dag.decimalPoint;
        }

        function name() public view returns(string memory) {
            return tokenName;
        }

        function symbol() public view returns(string memory) {
            return tokenSymbol;
        }

        function balanceOf(address voter) public view returns(uint256) {
            return dag.readReputation(voter);
        }
        
    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Events

        event SimpleEventForUpdates(string str, uint256 num);


        event joinTreeEvent(address voter, string name, address recipient);

        event changeNameEvent(address voter, string newName);


        event addDagVoteEvent(address voter, address recipient, uint256 weight);

        event removeDagVoteEvent(address voter, address recipient);


        event leaveTreeEvent(address voter);

        event switchPositionWithParentEvent(address voter);

        event moveTreeVoteEvent(address voter, address recipient);

        event DebugEvent(string str, uint256 randint);

    ////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree externals

        function lockTree() public {
            if (unlocked == true) {
                unlocked = false;
            }
        }

        // when we first join the tree
        function joinTree(address voter, string calldata voterName, address recipient) public {
            
            if (!unlocked) {
                require(msg.sender == voter, "A lT 1");
            }

            require (dag.treeVote[voter] == address(0), "A lT 2");
            require (dag.treeVote[recipient] != address(0), "A lT 3");
            require (dag.recTreeVoteCount[recipient] < 2, "A lT 4");

            dag.treeVote[voter] = recipient;
            dag.names[voter] = voterName;
            dag.recTreeVote[recipient][dag.recTreeVoteCount[recipient]] = voter;
            dag.recTreeVoteCount[recipient] = dag.recTreeVoteCount[recipient] + 1;

            dag.sentDagVoteDistDiff[voter] = 1000;
            dag.sentDagVoteDepthDiff[voter] = 1000;
            dag.recDagVoteDistDiff[voter] = 1000;
            dag.recDagVoteDepthDiff[voter] = 1000;
            
            // adding Dag Vote, copied from addDagVote
            (bool votable, bool voted, uint256 sdist, uint256 depth, , ) = AnthillInner.findSentDagVote( dag , voter, recipient);
            require ((votable) && (voted == false), "A lT 4");

            // add DagVotes. 
            AnthillInner.combinedDagAppendSdist( dag , voter, recipient, sdist, depth, 1);

            emit joinTreeEvent(voter, voterName, recipient);
        }

        // when we first join the tree without a parent
        function joinTreeAsRoot(address voter, string calldata voterName) public {
   
            emit SimpleEventForUpdates("", 1);

            if (!unlocked) {
                require (msg.sender == voter, "A jTAR 1");
            }          
  
            require (dag.treeVote[voter] == address(0), "A jTAR 2");
            require (dag.root == address(0), "A jTAR 3");

            dag.names[voter] = voterName;
            dag.treeVote[voter] = address(1);
            dag.root = voter;
            dag.recTreeVote[address(1)][0] = voter;
            dag.recTreeVoteCount[address(1)] =1;
            

            dag.sentDagVoteDistDiff[voter] = 1000;
            dag.sentDagVoteDepthDiff[voter] = 1000;
            dag.recDagVoteDistDiff[voter] = 1000;
            dag.recDagVoteDepthDiff[voter] = 1000;
        }

        function changeName(address voter, string calldata voterName)  public {
            if (!unlocked) {
                require (msg.sender == voter, "A jTAR 4");
            }

            require (dag.treeVote[voter] != address(0), "A jTAR 5");
            dag.names[voter] = voterName;

            emit changeNameEvent(voter, voterName);

        }

    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag externals
        // to add a vote to the dag.sentDagVote array, and also to the corresponding dag.recDagVote array
        function addDagVote(address voter, address recipient, uint256 weight) public {
            
            if (!unlocked) {
                require (msg.sender == voter, "A aDV 1");
            }

            (bool votable, bool voted, uint256 sdist, uint256 depth, , ) = AnthillInner.findSentDagVote( dag , voter, recipient);
            require ((votable) && (voted == false), "A aDV 2");

            // add DagVotes. 
            AnthillInner.combinedDagAppendSdist( dag , voter, recipient, sdist, depth, weight);

            emit addDagVoteEvent(voter, recipient, weight);
        }

        // to remove a vote from the dag.sentDagVote array, and also from the  corresponding dag.recDagVote arrays
        function removeDagVote(address voter, address recipient) public {
                     
            if (!unlocked) {
                require (msg.sender == voter, "A rDV 1");
            }


            // find the votes we delete
            (, bool voted, uint256 sdist, uint256 depth, uint256 sPos, ) = AnthillInner.findSentDagVote( dag , voter, recipient);
            require (voted == true, "A rDV 2");

            AnthillInner.safeRemoveSentDagVoteAtDistDepthPos(dag, voter, sdist, depth, sPos);

            emit removeDagVoteEvent(voter, recipient);
        }

    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global readers 

        function readDepth(address voter) public view returns(uint256){
            if (dag.treeVote[voter] == address(0)) return 0;
            if (dag.treeVote[voter] == address(1)) return 0;

            return readDepth(dag.treeVote[voter]) + 1;
        } 
    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Reputation Related

        
        // to calculate the reputation of a voter, i.e. the sum of the votes of the voter and all its descendants
        // not efficient
        function calculateReputation(address voter)  public returns (uint256){
            uint256 voterReputation = 0 ;
            if (voter == address(0)) return 0;

            for (uint256 dist=0; dist< dag.MAX_REL_ROOT_DEPTH; dist++){    
                for (uint256 depth=1; depth<= dag.MAX_REL_ROOT_DEPTH - dist; depth++){
                    for (uint256 count =0; count< AnthillInner.readRecDagVoteCount( dag , voter, dist, depth); count++) {
                    DagVote memory rDagVote = AnthillInner.readRecDagVote( dag , voter, dist, depth, count);
                        voterReputation += calculateReputation(rDagVote.id)*(rDagVote.weight)/ dag.sentDagVoteTotalWeight[rDagVote.id];
                    }
                }
            }
            // for the voter themselves
            voterReputation += 10**dag.decimalPoint;
            dag.reputation[voter] = voterReputation;
            return voterReputation;
        }


        function clearReputationCalculatedRec(address voter) public {
            if (readSentTreeVote(voter) == address(0)) {
                return;
            }

            dag.repIsCalculated[voter] = false;

            for (uint256 count =0; count< dag.recTreeVoteCount[voter]; count++) {
                clearReputationCalculatedRec(dag.recTreeVote[voter][count]);
            }

        }
        
        function calculateReputationRec(address voter) public {
            if (readSentTreeVote(voter) == address(0)) {
                return;
            }
            
            if (dag.repIsCalculated[voter]) {
                return;
            }

            for (uint256 count =0; count< dag.recTreeVoteCount[voter]; count++) {
                calculateReputationRec(dag.recTreeVote[voter][count]);
            }

            uint256 voterReputation = 0;

            for (uint256 dist=0; dist< dag.MAX_REL_ROOT_DEPTH; dist++){    
                for (uint256 depth=1; depth<= dag.MAX_REL_ROOT_DEPTH - dist; depth++){
                    for (uint256 count =0; count< AnthillInner.readRecDagVoteCount( dag , voter, dist, depth); count++) {
                    DagVote memory rDagVote = AnthillInner.readRecDagVote( dag , voter, dist, depth, count);
                        voterReputation += dag.reputation[rDagVote.id]*(rDagVote.weight)/ dag.sentDagVoteTotalWeight[rDagVote.id];
                    }
                }
            }

            voterReputation += 10**dag.decimalPoint;
            dag.reputation[voter] = voterReputation;

            dag.repIsCalculated[voter] = true;
           
        }


        function recalculateAllReputation() public {
            clearReputationCalculatedRec(dag.root);
            calculateReputationRec(dag.root);
        }
    ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global external

        
        function leaveTree(address voter) public {

            if (!unlocked) {
                require (msg.sender == voter, "A lT 1");
            }
            
            dag.removeSentDagVoteComplete( voter);
            dag.removeRecDagVoteComplete(  voter);

            dag.handleLeavingVoterBranch(  voter);
            dag.treeVote[voter] = address(0);

            emit leaveTreeEvent(voter);
        }

        function switchPositionWithParent(address voter) public {

            if (!unlocked) {
                require (msg.sender == voter, "A lT 2");
            }

            address parent = dag.treeVote[voter];
            require (parent != address(0), "A lT 3");
            require (parent != address(1), "A lT 4");
            address gparent = dag.treeVote[parent];
            
            uint256 voterRep = calculateReputation(voter);
            uint256 parentRep = calculateReputation(parent);

            require (voterRep > parentRep, "A lT 5");
            
            dag.handleDagVoteMoveFall(  parent, parent, voter, 0, 0);
            dag.handleDagVoteMoveRise(  voter, gparent, parent, 2, 2);
            
            dag.switchTreeVoteWithParent( voter);

            emit switchPositionWithParentEvent(voter);
        }

        struct CheckPositionResult {
            bool isLowerOrEqual;
            bool isSimilar;
            bool isHigher;
            uint256 lowerSDist;
            uint256 lowerRDist;
            uint256 lowerDepth;
            uint256 simDist;
            uint256 simDepth;
            uint256 higherDist;
            uint256 higherDepth;
        }

        function moveTreeVote(address voter, address recipient) external {
            {
                if (!unlocked) {
                    require (msg.sender == voter, "A mTV 1");
                }
            }
            {
                require (dag.treeVote[voter] != address(0), "A mTV 2");
                require (dag.treeVote[recipient] != address(0), "A mTV 3");
                require (dag.recTreeVoteCount[recipient] < 2, "A mTV 4");
            }
            CheckPositionResult memory positionResult = _checkPosition(voter, recipient);

            {
                // we need to leave the tree nowm so that our descendants can rise. 
                address parent= dag.treeVote[voter];
                dag.handleLeavingVoterBranch( voter);

                if ((positionResult.lowerRDist == 0) && (positionResult.isLowerOrEqual)){
                    // if we are jumping to our descendant who just rose, we have to modify the lowerSDist
                    if (  dag.findNthParent( recipient, positionResult.lowerDepth)==parent){
                        positionResult.lowerSDist = positionResult.lowerSDist - 1;
                        positionResult.lowerDepth = positionResult.lowerDepth - 1;
                    }
                }
            }

            // currently we don't support position swithces here, so replaced address is always 0. 
            if (positionResult.isLowerOrEqual){
                dag.handleDagVoteMoveFall( voter, recipient, address(0), positionResult.lowerRDist, positionResult.lowerDepth);
            } else if (positionResult.isSimilar){
                dag.handleDagVoteMoveRise( voter, recipient, address(0), positionResult.simDist, positionResult.simDepth);
            } else if ((positionResult.isHigher) && (positionResult.higherDepth > 1)){
                dag.handleDagVoteMoveRise( voter, recipient, address(0), positionResult.higherDist, positionResult.higherDepth);
            }  else {
                // we completely jumped out. remove all dagVotes. 
                dag.removeSentDagVoteComplete( voter);
                dag.removeRecDagVoteComplete( voter);            
            }
            // handle tree votes
            // there is a single twise here, if recipient the descendant of the voter that rises.
            dag.addTreeVote( voter, recipient);

            emit moveTreeVoteEvent(voter, recipient);
        }


        function _checkPosition(address voter, address recipient) internal view returns (CheckPositionResult memory result) {
            (address relRoot, ) = AnthillInner.findRelRoot( dag , voter);
            (bool isLowerOrEqual, uint256 lowerSDist, uint256 lowerDepth) = AnthillInner.findSDistDepth( dag , recipient, voter);
            uint256 lowerRDist = lowerSDist - lowerDepth;
            (bool isSimilar, uint256 simDist, uint256 simDepth) = AnthillInner.findSDistDepth( dag , voter, recipient);
            (bool isHigher, uint256 higherRDist, uint256 higherDepthToRelRoot) = AnthillInner.findSDistDepth( dag , recipient, relRoot);
            uint256 higherDepth = dag.MAX_REL_ROOT_DEPTH - higherDepthToRelRoot;
            uint256 higherDist = higherRDist + higherDepth;

            result.isLowerOrEqual = isLowerOrEqual;
            result.isSimilar = isSimilar;
            result.isHigher = isHigher;
            result.lowerSDist = lowerSDist;
            result.lowerRDist = lowerRDist;
            result.lowerDepth = lowerDepth;
            result.simDist = simDist;
            result.simDepth = simDepth;
            result.higherDist = higherDist;
            result.higherDepth = higherDepth;
        }

    ///////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////// imported from AnthillInner library, mostly view functions. (Non-view functions  are for testing, should be commented out for deployment.
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Variable readers 
        // root/base 
            function readRoot() public view returns(address){
                return dag.readRoot();
            }

            function readMaxRelRootDepth() public view returns(uint256){
                return dag.readMaxRelRootDepth();
            }

        // for node properties
            function readReputation( address voter) public view returns(uint256){
                return dag.readReputation( voter);
            }

            function readName( address voter) public view returns(string memory){
                return dag.readName( voter);
            }

        // for tree votes
            function readSentTreeVote( address voter) public view returns(address){
                return dag.readSentTreeVote( voter);
            }

            function readRecTreeVoteCount( address recipient) public view returns(uint256){
                return dag.readRecTreeVoteCount( recipient);
            }

            function readRecTreeVote( address recipient, uint256 votePos) public view returns(address){
                return dag.readRecTreeVote( recipient, votePos);
            }

        // for sent dag 
            
            function readSentDagVoteDistDiff( address voter) external view returns(uint256){
                return dag.readSentDagVoteDistDiff( voter);
            }

            function readSentDagVoteDepthDiff( address voter) external view returns(uint256){
                return dag.readSentDagVoteDepthDiff( voter);
            }

            function readSentDagVoteCount( address voter, uint256 sdist, uint256 depth) public view returns(uint256){
                return dag.readSentDagVoteCount( voter, sdist, depth);
            }

            function readSentDagVote( address voter, uint256 sdist, uint256 depth, uint256 votePos) public view returns( DagVote memory){
                return dag.readSentDagVote( voter, sdist, depth, votePos);
            }

        
            function readSentDagVoteTotalWeight( address voter) public view returns( uint256){
                return dag.readSentDagVoteTotalWeight( voter);
            }

        // for rec Dag votes

            function readRecDagVoteDistDiff( address recipient) external view returns(uint256){
                return dag.readRecDagVoteDistDiff( recipient);
            }

            function readRecDagVoteDepthDiff( address recipient) public view returns(uint256){
                return dag.readRecDagVoteDepthDiff( recipient);
            }


            function readRecDagVoteCount( address recipient, uint256 rdist, uint256 depth) public view returns(uint256){
                return dag.readRecDagVoteCount( recipient, rdist, depth);
            }

            function readRecDagVote( address recipient, uint256 rdist, uint256 depth, uint256 votePos) public view returns(DagVote memory){
                return dag.readRecDagVote( recipient, rdist, depth, votePos);
            }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree finder 

        function findRecTreeVotePos( address voter, address recipient) public view returns (bool voted, uint256 votePos) {
            return dag.findRecTreeVotePos( voter, recipient);
        }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree internal
        function removeTreeVote(address voter) internal {
            dag.removeTreeVote( voter);
        }
    
        function addTreeVote(address voter, address recipient) internal {
            dag.addTreeVote( voter, recipient);
        }

        function addTreeVoteWithoutCheck(address voter, address recipient) internal {
            dag.addTreeVoteWithoutCheck( voter, recipient);
        }

        function switchTreeVoteWithParent(address voter) internal {
            dag.switchTreeVoteWithParent( voter);
        }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Local tree finders
        
        function findNthParent(address voter, uint256 height) public view returns (address parent){
            return dag.findNthParent( voter, height);
        }

        // to find our relative dag.root, our ancestor at depth dag.MAX_REL_ROOT_DEPTH
        function findRelRoot( address voter) public view returns (address relRoot, uint256 relDepth){
            return dag.findRelRoot( voter);
        }

        // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative dag.root
        function findRelDepth(address voter, address recipient) public view returns (bool isLocal, uint256 relDepth){
            return dag.findRelDepth( voter, recipient);
        }

        // to find the distance between voter and recipient, within maxDistance. 
        // THIS IS ACTUALLY A GLOBAL FUNTION!
        function findDistAtSameDepth(address add1, address add2) public view returns (bool isSameDepth, uint256 distance) {
            return dag.findDistAtSameDepth( add1, add2);
        }

        // 
        function findSDistDepth(address voter, address recipient) public view returns (bool isLocal, uint256 distance, uint256 relDepth){
            return dag.findSDistDepth( voter, recipient);
        }

        

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// DAG finders
        // to check the existence and to find the position of a vote in a given row of the sentDagVote array
        function findSentDagVotePosAtDistDepth(address voter, address recipient, uint256 sdist,  uint256 depth) public view returns (bool voted, uint256 votePos, DagVote memory vote){
            return dag.findSentDagVotePosAtDistDepth( voter, recipient, sdist, depth);
        }

        // to check the existence and to find the position of a vote in a given row of the recDagVote array
        function findRecDagVotePosAtDistDepth(address voter, address recipient, uint256 rdist, uint256 depth) public view returns (bool voted, uint256 votePos, DagVote memory vote){
            return dag.findRecDagVotePosAtDistDepth( voter, recipient, rdist, depth); 
        }

        function findLastSentDagVoteAtDistDepth(address voter, uint256 sdist, uint256 depth) public view returns (bool voted, uint256 votePos, DagVote memory vote){
            return dag.findLastSentDagVoteAtDistDepth( voter, sdist, depth);
        }

        function findLastRecDagVoteAtDistDepth(address recipient, uint256 rdist, uint256 depth) public view returns (bool voted, uint256 votePos, DagVote memory vote){
            return dag.findLastRecDagVoteAtDistDepth( recipient, rdist, depth);
        }

        // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
        function findSentDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint256 sdist,  uint256 depth, uint256 votePos, DagVote memory dagVote){ 
            return dag.findSentDagVote( voter, recipient);
        }

        // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
        function findRecDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint256 rdist, uint256 depth, uint256 votePos, DagVote memory dagVote){
            return dag.findRecDagVote( voter, recipient);
        }


    // used for testing: 
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag internals. Core logic. 
        ///////////// Single vote changes
            ///////////// appending a vote

                function sentDagAppend( address voter, uint256 sdist, uint256 depth, address recipient, uint256 weight, uint256 rPos ) internal{
                    return dag.sentDagAppend( voter, sdist, depth, recipient, weight, rPos);
                }

                function recDagAppend( address recipient, uint256 rdist, uint256 depth, address voter, uint256 weight, uint256 sPos ) public{
                    require (unlocked == true, "A rDA 1");
                    return dag.recDagAppend( recipient, rdist, depth, voter, weight, sPos);   
                }

                function combinedDagAppendSdist( address voter, address recipient,  uint256 sdist, uint256 depth, uint256 weight) internal{
                    return dag.combinedDagAppendSdist( voter, recipient, sdist, depth, weight);   
                }

            ///////////// changing position

                function changePositionSent( address voter, uint256 sdist,  uint256 depth, uint256 sPos, uint256 newRPos) internal {
                    return dag.changePositionSent( voter, sdist, depth, sPos, newRPos);
                }

                function changePositionRec( address recipient, uint256 rdist, uint256 depth, uint256 rPos, uint256 newSPos) internal{
                    return dag.changePositionRec( recipient, rdist, depth, rPos, newSPos);
                }   

            

            ///////////// delete and removal functions
                ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.
                
                /// careful, does not delete the opposite or deacrese count! Do not call, call unsafeReplace..  or safeRemove.. instead
                function unsafeDeleteLastSentDagVoteAtDistDepth( address voter, uint256 sdist, uint256 depth) internal {
                    delete dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+ sdist][dag.sentDagVoteDepthDiff[voter]+depth][dag.readSentDagVoteCount( voter, sdist, depth)-1];
                }

                /// careful, does not delete the opposite, or decrease count! Do not call, call unsafeReplace..  or safeRemove.. instead
                function unsafeDeleteLastRecDagVoteAtDistDepth( address recipient, uint256 rdist, uint256 depth) internal {
                    delete dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+ rdist][dag.recDagVoteDepthDiff[recipient]+depth][dag.readRecDagVoteCount( recipient, rdist, depth)-1];
                }   

                // careful does not delete the opposite! Always call with opposite, or do something with the other vote
                function unsafeReplaceSentDagVoteAtDistDepthPosWithLast( address voter, uint256 sdist, uint256 depth, uint256 sPos) internal {
                    dag.unsafeReplaceSentDagVoteAtDistDepthPosWithLast( voter, sdist, depth, sPos);
                } 

                /// careful, does not delete the opposite!
                function unsafeReplaceRecDagVoteAtDistDepthPosWithLast( address recipient, uint256 rdist, uint256 depth, uint256 rPos) public {
                    require (unlocked == true, "A uSRDV 1");
                    dag.unsafeReplaceRecDagVoteAtDistDepthPosWithLast( recipient, rdist, depth, rPos);
                } 

                function safeRemoveSentDagVoteAtDistDepthPos(address voter, uint256 sdist, uint256 depth, uint256 sPos) internal {
                    dag.safeRemoveSentDagVoteAtDistDepthPos( voter, sdist, depth, sPos);    
                }

                function safeRemoveRecDagVoteAtDistDepthPos( address recipient, uint256 rdist, uint256 depth, uint256 rPos) internal {
                    dag.safeRemoveRecDagVoteAtDistDepthPos( recipient, rdist, depth, rPos);
                }

            ///////////// change dist and depth
                function changeDistDepthSent( address voter, uint256 sdist, uint256 depth, uint256 sPos, uint256 newSDist, uint256 newDepth, address recipient, uint256 rPos, uint256 weight) public{
                    require (unlocked == true, "A cDDS 1");
                    // here it is ok to use unsafe, as the the vote is moved, not removed
                   dag.changeDistDepthSent( voter, sdist, depth, sPos, newSDist, newDepth, recipient, rPos, weight);
                }

                function changeDistDepthRec( address recipient, uint256 rdist, uint256 depth, uint256 rPos, uint256 newRDist, uint256 newDepth, address voter, uint256 sPos, uint256 weight) public{
                    require (unlocked == true, "A cDDR 1");
                    // here it is ok to use unsafe, as the the vote is moved, not removed
                    dag.changeDistDepthRec( recipient, rdist, depth, rPos, newRDist, newDepth, voter, sPos, weight);
                }

        ///////////// Cell removal and handler functions 
            ///////////// removal 
                // to remove a row of votes from the dag.sentDagVote array, and the corresponding votes from the dag.recDagVote arrays
                function removeSentDagVoteCell( address voter, uint256 sdist, uint256 depth) internal {
                    dag.removeSentDagVoteCell( voter, sdist, depth);
                }

                // to remove a row of votes from the dag.recDagVote array, and the corresponding votes from the dag.sentDagVote arrays
                function removeRecDagVoteCell( address recipient, uint256 rdist, uint256 depth) public {
                    require (unlocked == true, "A rRDVC 1");
                    dag.removeRecDagVoteCell( recipient, rdist, depth);
                }

            
            
            ///////////// dist depth on opposite 
                function changeDistDepthFromSentCellOnOp( address voter, uint256 sdist, uint256 depth, uint256 oldSDist, uint256 oldDepth) internal {
                    dag.changeDistDepthFromSentCellOnOp( voter, sdist, depth, oldSDist, oldDepth);
                }

                function changeDistDepthFromRecCellOnOp( address recipient, uint256 rdist, uint256 depth, uint256 oldRDist, uint256 oldDepth) public {
                    require (unlocked == true, "A cDDFR 1");
                    dag.changeDistDepthFromRecCellOnOp( recipient, rdist, depth, oldRDist, oldDepth);
                }
            
            ///////////// move cell

                function moveSentDagVoteCell(address voter, uint256 sdist, uint256 depth, uint256 newSDist, uint256 newDepth) internal {
                    dag.moveSentDagVoteCell( voter, sdist, depth, newSDist, newDepth);
                }

                function moveRecDagVoteCell(address recipient, uint256 rdist, uint256 depth, uint256 newRDist, uint256 newDepth) internal {
                    dag.moveRecDagVoteCell( recipient, rdist, depth, newRDist, newDepth);
                }

        ///////////// Line  remover and sorter functions
            ///////////// Line removers

                function removeSentDagVoteLineDepthEqualsValue( address voter, uint256 value) internal {
                    dag.removeSentDagVoteLineDepthEqualsValue( voter, value);
                }

                function removeRecDagVoteLineDepthEqualsValue( address voter, uint256 value) internal {
                    dag.removeRecDagVoteLineDepthEqualsValue( voter, value);
                }

                function removeSentDagVoteLineDistEqualsValue( address voter, uint256 value) internal {
                    dag.removeSentDagVoteLineDistEqualsValue( voter, value);
                }


            ///////////// Sort Cell into line
                function sortSentDagVoteCell( address voter, uint256 sdist, uint256 depth, address anscestorAtDepth) internal {
                    dag.sortSentDagVoteCell( voter, sdist, depth, anscestorAtDepth); 
                }

                function sortRecDagVoteCell( address recipient, uint256 rdist, uint256 depth,  address newTreeVote) internal {
                    dag.sortRecDagVoteCell( recipient, rdist, depth, newTreeVote);
                }

                function sortRecDagVoteCellDescendants( address recipient, uint256 depth, address replaced) internal {
                    dag.sortRecDagVoteCellDescendants( recipient, depth, replaced);
                }
        
        ///////////// Area/whole triangle changers
                     
            ///////////// Depth and pos change across graph
                function increaseDistDepthFromSentOnOpFalling( address voter, uint256 diff) internal {
                    dag.increaseDistDepthFromSentOnOpFalling( voter, diff); 
                }

                function decreaseDistDepthFromSentOnOpRising( address voter, uint256 diff) internal {
                    dag.decreaseDistDepthFromSentOnOpRising( voter, diff);
                }

                function changeDistDepthFromRecOnOpFalling( address voter, uint256 diff) internal {
                    dag.changeDistDepthFromRecOnOpFalling( voter, diff);
                }

                function changeDistDepthFromRecOnOpRising( address voter, uint256 diff) internal {
                    dag.changeDistDepthFromRecOnOpRising( voter, diff);
                }

            ///////////// Movers
                function moveSentDagVoteUpRightFalling( address voter, uint256 diff) internal {
                    dag.moveSentDagVoteUpRightFalling( voter, diff);
                }

                function moveSentDagVoteDownLeftRising( address voter, uint256 diff) internal {
                    dag.moveSentDagVoteDownLeftRising( voter, diff);
                }

                function moveRecDagVoteUpRightFalling( address voter, uint256 diff) internal {
                    dag.moveRecDagVoteUpRightFalling( voter, diff);
                }

                function moveRecDagVoteDownLeftRising( address voter, uint256 diff) public {
                    require (unlocked == true, "A mRDVDLR");
                    dag.moveRecDagVoteDownLeftRising( voter, diff);
                }
            ///////////// Collapsing to, and sorting from columns

                function collapseSentDagVoteIntoColumn( address voter, uint256 sdistDestination) public {
                    require (unlocked == true, "A cSDVIC");
                    dag.collapseSentDagVoteIntoColumn( voter, sdistDestination);
                }            

                function collapseRecDagVoteIntoColumn(  address voter, uint256 rdistDestination) public {
                    require (unlocked == true, "A cRDVIC");
                    dag.collapseRecDagVoteIntoColumn( voter, rdistDestination);
                }

                function sortSentDagVoteColumn( address voter, uint256 sdist, address newTreeVote) public {
                    require (unlocked == true, "A sSDVC");
                    dag.sortSentDagVoteColumn( voter, sdist, newTreeVote);
                }

                function sortRecDagVoteColumn(  address recipient, uint256 rdist, address newTreeVote) public {
                    require (unlocked == true, "A sRDVC");
                    dag.sortRecDagVoteColumn( recipient, rdist, newTreeVote);
                }

                function sortRecDagVoteColumnDescendants(  address recipient, address replaced) public {
                    require (unlocked == true, "A sRDVCD");
                    dag.sortRecDagVoteColumnDescendants( recipient, replaced);
                }

            ///////////// Combined dag Square vote handler for rising falling, a certain depth, with passing the new recipient in for selction    

                function handleDagVoteMoveRise( address voter, address recipient, address replaced, uint256 moveDist, uint256 depthToRec ) public {
                    require (unlocked == true, "A hDVMR");
                    dag.handleDagVoteMoveRise( voter, recipient, replaced, moveDist, depthToRec);
                }

                function handleDagVoteMoveFall( address voter, address recipient, address replaced, uint256 moveDist, uint256 depthToRec) public {
                    require (unlocked == true, "A hDVMF");
                    dag.handleDagVoteMoveFall( voter, recipient, replaced, moveDist, depthToRec);
                }



    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global internal
        
        function pullUpBranch(address pulledVoter, address parent) public {
            require (unlocked == true, "A pUB");
           dag.pullUpBranch( pulledVoter, parent);
        }
        
        function handleLeavingVoterBranch( address voter) public {
            require (unlocked == true, "A hLVB");
            dag.handleLeavingVoterBranch( voter);
        }

}


