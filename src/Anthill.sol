// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import {Dag,  DagVote, AnthillInner} from "./AnthillInner.sol";

contract Anthill {

    event SimpleEventForUpdates(string str, uint256 randint);

    constructor() {
        dag.decimalPoint = 18;
        dag.MAX_REL_ROOT_DEPTH = 6;
    }

    ////////////////////////////////////////////
    //// State variables   
        using AnthillInner for Dag; 
        Dag public dag; 
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree externals


        // when we first join the tree
        function joinTree(address voter, string calldata name, address recipient) public {
            emit SimpleEventForUpdates("", 0);
            
            assert (msg.sender == voter);

            assert (dag.treeVote[voter] == address(0));
            assert (dag.treeVote[recipient] != address(0));
            assert (dag.recTreeVoteCount[recipient] < 2);

            dag.treeVote[voter] = recipient;
            dag.names[voter] = name;
            dag.recTreeVote[recipient][dag.recTreeVoteCount[recipient]] = voter;
            dag.recTreeVoteCount[recipient] = dag.recTreeVoteCount[recipient] + 1;

            dag.sentDagVoteDistDiff[voter] = 1000;
            dag.sentDagVoteDepthDiff[voter] = 1000;
            dag.recDagVoteDistDiff[voter] = 1000;
            dag.recDagVoteDepthDiff[voter] = 1000;

            addDagVote(voter, recipient, 1);

        }

        // when we first join the tree without a parent
        function joinTreeAsRoot(address voter, string calldata name) public {
   
            emit SimpleEventForUpdates("", 1);

            assert (msg.sender == voter);
  
            assert (dag.treeVote[voter] == address(0));
            assert (dag.root == address(0));

            dag.names[voter] = name;
            dag.treeVote[voter] = address(1);
            dag.root = voter;
            

            dag.sentDagVoteDistDiff[voter] = 1000;
            dag.sentDagVoteDepthDiff[voter] = 1000;
            dag.recDagVoteDistDiff[voter] = 1000;
            dag.recDagVoteDepthDiff[voter] = 1000;
        }

        function changeName(address voter, string calldata name)  public {
            assert (msg.sender == voter);

            emit SimpleEventForUpdates("", 0);
            assert (dag.treeVote[voter] != address(0));
            dag.names[voter] = name;
        }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag externals
        // to add a vote to the dag.sentDagVote array, and also to the corresponding dag.recDagVote array
        function addDagVote(address voter, address recipient, uint32 weight) public {
            
            assert (msg.sender == voter);

            emit SimpleEventForUpdates("", 0);

            (bool votable, bool voted, uint32 sdist, uint32 depth, , ) = AnthillInner.findSentDagVote( dag , voter, recipient);
            assert ((votable) && (voted == false));

            // add DagVotes. 
            AnthillInner.combinedDagAppendSdist( dag , voter, recipient, sdist, depth, weight);    
        }

        // to remove a vote from the dag.sentDagVote array, and also from the  corresponding dag.recDagVote arrays
        function removeDagVote(address voter, address recipient) public {
           
            emit SimpleEventForUpdates("", 0);
          
            assert (msg.sender == voter);


            // find the votes we delete
            (, bool voted, uint32 sdist, uint32 depth, uint32 sPos, ) = AnthillInner.findSentDagVote( dag , voter, recipient);
            assert (voted == true);

            AnthillInner.safeRemoveSentDagVoteAtDistDepthPos(dag, voter, sdist, depth, sPos);
        }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global readers 

        function readDepth(address voter) public view returns(uint32){
            if (dag.treeVote[voter] == address(0)) return 0;
            if (dag.treeVote[voter] == address(1)) return 0;

            return readDepth(dag.treeVote[voter]) + 1;
        } 

        // to calculate the reputation of a voter, i.e. the sum of the votes of the voter and all its descendants
        function calculateReputation(address voter)  public returns (uint256){
            uint256 voterReputation = 0 ;
            if (voter == address(0)) return 0;

            for (uint32 dist=0; dist< dag.MAX_REL_ROOT_DEPTH; dist++){    
                for (uint32 depth=1; depth<= dag.MAX_REL_ROOT_DEPTH - dist; depth++){
                    for (uint32 count =0; count< AnthillInner.readRecDagVoteCount( dag , voter, dist, depth); count++) {
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

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global external

        
        function leaveTree(address voter) public {

            assert (msg.sender == voter);

            emit SimpleEventForUpdates("", 0);
            
            dag.removeSentDagVoteComplete( voter);
            dag.removeRecDagVoteComplete(  voter);

            dag.handleLeavingVoterBranch(  voter);
            dag.treeVote[voter] = address(0);
        }

        function switchPositionWithParent(address voter) public {

            assert (msg.sender == voter);

            emit SimpleEventForUpdates("", 0);

            address parent = dag.treeVote[voter];
            assert (parent != address(0));
            assert (parent != address(1));
            address gparent = dag.treeVote[parent];
            
            uint256 voterRep = calculateReputation(voter);
            uint256 parentRep = calculateReputation(parent);

            assert (voterRep > parentRep);
            
            dag.handleDagVoteMoveFall(  parent, parent, voter, 0, 0);
            dag.handleDagVoteMoveRise(  voter, gparent, parent, 2, 2);
            
            dag.switchTreeVoteWithParent( voter);
        }

        function moveTreeVote(address voter, address recipient) external {
 
            assert (msg.sender == voter);


            emit SimpleEventForUpdates("", 0);

            assert (dag.treeVote[voter] != address(0));

            assert (dag.treeVote[recipient] != address(0));
            assert (dag.recTreeVoteCount[recipient] < 2);

            (address relRoot, ) = AnthillInner.findRelRoot( dag , voter);
            (bool isLowerOrEqual, uint32 lowerSDist, uint32 lowerDepth) = AnthillInner.findSDistDepth( dag , recipient, voter);
            uint32 lowerRDist = lowerSDist - lowerDepth;
            (bool isSimilar, uint32 simDist, uint32 simDepth) = AnthillInner.findSDistDepth( dag , voter, recipient);
            (bool isHigher, uint32 higherRDist, uint32 higherDepthToRelRoot) = AnthillInner.findSDistDepth( dag , recipient, relRoot);
            uint32 higherDepth = dag.MAX_REL_ROOT_DEPTH - higherDepthToRelRoot;
            uint32 higherDist = higherRDist + higherDepth;

            // we need to leave the tree nowm so that our descendants can rise. 
            address parent= dag.treeVote[voter];
            dag.handleLeavingVoterBranch( voter);

            if ((lowerRDist == 0) && (isLowerOrEqual)){
                // if we are jumping to our descendant who just rose, we have to modify the lowerSDist
                if (  dag.findNthParent( recipient, lowerDepth)==parent){
                    lowerSDist = lowerSDist - 1;
                    lowerDepth = lowerDepth - 1;
                }
            }

            // currently we don't support position swithces here, so replaced address is always 0. 
            if (isLowerOrEqual){
                dag.handleDagVoteMoveFall( voter, recipient, address(0), lowerRDist, lowerDepth);
            } else if (isSimilar){
                dag.handleDagVoteMoveRise( voter, recipient, address(0), simDist, simDepth);
            } else if ((isHigher) && (higherDepth > 1)){
                dag.handleDagVoteMoveRise( voter, recipient, address(0), higherDist, higherDepth);
            }  else {
                // we completely jumped out. remove all dagVotes. 
                dag.removeSentDagVoteComplete( voter);
                dag.removeRecDagVoteComplete( voter);            
            }
            // handle tree votes
            // there is a single twise here, if recipient the descendant of the voter that rises.
            dag.addTreeVote( voter, recipient);
        }


    ///////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////// imported from AnthillInner library. (Todo: remove unnecessary functions/make others internal or comment out completely, its for testing.)
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Variable readers 
        // root/base 
            function readRoot() public view returns(address){
                return dag.readRoot();
            }

            function readMaxRelRootDepth() public view returns(uint32){
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

            function readRecTreeVoteCount( address recipient) public view returns(uint32){
                return dag.readRecTreeVoteCount( recipient);
            }

            function readRecTreeVote( address recipient, uint32 votePos) public view returns(address){
                return dag.readRecTreeVote( recipient, votePos);
            }

        // for sent dag 
            
            function readSentDagVoteDistDiff( address voter) external view returns(uint32){
                return dag.readSentDagVoteDistDiff( voter);
            }

            function readSentDagVoteDepthDiff( address voter) external view returns(uint32){
                return dag.readSentDagVoteDepthDiff( voter);
            }

            function readSentDagVoteCount( address voter, uint32 sdist, uint32 depth) public view returns(uint32){
                return dag.readSentDagVoteCount( voter, sdist, depth);
            }

            function readSentDagVote( address voter, uint32 sdist, uint32 depth, uint32 votePos) public view returns( DagVote memory){
                return dag.readSentDagVote( voter, sdist, depth, votePos);
            }

        
            function readSentDagVoteTotalWeight( address voter) public view returns( uint32){
                return dag.readSentDagVoteTotalWeight( voter);
            }

        // for rec Dag votes

            function readRecDagVoteDistDiff( address recipient) external view returns(uint32){
                return dag.readRecDagVoteDistDiff( recipient);
            }

            function readRecDagVoteDepthDiff( address recipient) public view returns(uint32){
                return dag.readRecDagVoteDepthDiff( recipient);
            }


            function readRecDagVoteCount( address recipient, uint32 rdist, uint32 depth) public view returns(uint32){
                return dag.readRecDagVoteCount( recipient, rdist, depth);
            }

            function readRecDagVote( address recipient, uint32 rdist, uint32 depth, uint32 votePos) public view returns(DagVote memory){
                return dag.readRecDagVote( recipient, rdist, depth, votePos);
            }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree finder 

        function findRecTreeVotePos( address voter, address recipient) public view returns (bool voted, uint32 votePos) {
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
        
        function findNthParent(address voter, uint32 height) public view returns (address parent){
            return dag.findNthParent( voter, height);
        }

        // to find our relative dag.root, our ancestor at depth dag.MAX_REL_ROOT_DEPTH
        function findRelRoot( address voter) public view returns (address relRoot, uint32 relDepth){
            return dag.findRelRoot( voter);
        }

        // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative dag.root
        function findRelDepth(address voter, address recipient) public view returns (bool isLocal, uint32 relDepth){
            return dag.findRelDepth( voter, recipient);
        }

        // to find the distance between voter and recipient, within maxDistance. 
        // THIS IS ACTUALLY A GLOBAL FUNTION!
        function findDistAtSameDepth(address add1, address add2) public view returns (bool isSameDepth, uint32 distance) {
            return dag.findDistAtSameDepth( add1, add2);
        }

        // 
        function findSDistDepth(address voter, address recipient) public view returns (bool isLocal, uint32 distance, uint32 relDepth){
            return dag.findSDistDepth( voter, recipient);
        }

        

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// DAG finders
        // to check the existence and to find the position of a vote in a given row of the sentDagVote array
        function findSentDagVotePosAtDistDepth(address voter, address recipient, uint32 sdist,  uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return dag.findSentDagVotePosAtDistDepth( voter, recipient, sdist, depth);
        }

        // to check the existence and to find the position of a vote in a given row of the recDagVote array
        function findRecDagVotePosAtDistDepth(address voter, address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return dag.findRecDagVotePosAtDistDepth( voter, recipient, rdist, depth); 
        }

        function findLastSentDagVoteAtDistDepth(address voter, uint32 sdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return dag.findLastSentDagVoteAtDistDepth( voter, sdist, depth);
        }

        function findLastRecDagVoteAtDistDepth(address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return dag.findLastRecDagVoteAtDistDepth( recipient, rdist, depth);
        }

        // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
        function findSentDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 sdist,  uint32 depth, uint32 votePos, DagVote memory dagVote){ 
            return dag.findSentDagVote( voter, recipient);
        }

        // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
        function findRecDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 rdist, uint32 depth, uint32 votePos, DagVote memory dagVote){
            return dag.findRecDagVote( voter, recipient);
        }



    // /////////////////////////////////////////////////////////////////////////////////////////////////////////
    // //// Dag internals. Core logic. 
    //     ///////////// Single vote changes
    //         ///////////// appending a vote

    //             function sentDagAppend( address voter, uint32 sdist, uint32 depth, address recipient, uint32 weight, uint32 rPos ) internal{
    //                 return dag.sentDagAppend( voter, sdist, depth, recipient, weight, rPos);
    //             }

    //             function recDagAppend( address recipient, uint32 rdist, uint32 depth, address voter, uint32 weight, uint32 sPos ) public{
    //                 return dag.recDagAppend( recipient, rdist, depth, voter, weight, sPos);   
    //             }

    //             function combinedDagAppendSdist( address voter, address recipient,  uint32 sdist, uint32 depth, uint32 weight) internal{
    //                 return dag.combinedDagAppendSdist( voter, recipient, sdist, depth, weight);   
    //             }

    //         ///////////// changing position

    //             function changePositionSent( address voter, uint32 sdist,  uint32 depth, uint32 sPos, uint32 newRPos) internal {
    //                 return dag.changePositionSent( voter, sdist, depth, sPos, newRPos);
    //             }

    //             function changePositionRec( address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newSPos) internal{
    //                 return dag.changePositionRec( recipient, rdist, depth, rPos, newSPos);
    //             }   

            

    //         ///////////// delete and removal functions
    //             ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.
                
    //             /// careful, does not delete the opposite or deacrese count! Do not call, call unsafeReplace..  or safeRemove.. instead
    //             function unsafeDeleteLastSentDagVoteAtDistDepth( address voter, uint32 sdist, uint32 depth) internal {
    //                 delete dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+ sdist][dag.sentDagVoteDepthDiff[voter]+depth][dag.readSentDagVoteCount( voter, sdist, depth)-1];
    //             }

    //             /// careful, does not delete the opposite, or decrease count! Do not call, call unsafeReplace..  or safeRemove.. instead
    //             function unsafeDeleteLastRecDagVoteAtDistDepth( address recipient, uint32 rdist, uint32 depth) internal {
    //                 delete dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+ rdist][dag.recDagVoteDepthDiff[recipient]+depth][dag.readRecDagVoteCount( recipient, rdist, depth)-1];
    //             }   

    //             // careful does not delete the opposite! Always call with opposite, or do something with the other vote
    //             function unsafeReplaceSentDagVoteAtDistDepthPosWithLast( address voter, uint32 sdist, uint32 depth, uint32 sPos) internal {
    //                 dag.unsafeReplaceSentDagVoteAtDistDepthPosWithLast( voter, sdist, depth, sPos);
    //             } 

    //             /// careful, does not delete the opposite!
    //             function unsafeReplaceRecDagVoteAtDistDepthPosWithLast( address recipient, uint32 rdist, uint32 depth, uint32 rPos) public {
    //                 dag.unsafeReplaceRecDagVoteAtDistDepthPosWithLast( recipient, rdist, depth, rPos);
    //             } 

    //             function safeRemoveSentDagVoteAtDistDepthPos(address voter, uint32 sdist, uint32 depth, uint32 sPos) internal {
    //                 dag.safeRemoveSentDagVoteAtDistDepthPos( voter, sdist, depth, sPos);    
    //             }

    //             function safeRemoveRecDagVoteAtDistDepthPos( address recipient, uint32 rdist, uint32 depth, uint32 rPos) internal {
    //                 dag.safeRemoveRecDagVoteAtDistDepthPos( recipient, rdist, depth, rPos);
    //             }

    //         ///////////// change dist and depth
    //             function changeDistDepthSent( address voter, uint32 sdist, uint32 depth, uint32 sPos, uint32 newSDist, uint32 newDepth, address recipient, uint32 rPos, uint32 weight) public{
    //                 // here it is ok to use unsafe, as the the vote is moved, not removed
    //                dag.changeDistDepthSent( voter, sdist, depth, sPos, newSDist, newDepth, recipient, rPos, weight);
    //             }

    //             function changeDistDepthRec( address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newRDist, uint32 newDepth, address voter, uint32 sPos, uint32 weight) public{
    //                 // here it is ok to use unsafe, as the the vote is moved, not removed
    //                 dag.changeDistDepthRec( recipient, rdist, depth, rPos, newRDist, newDepth, voter, sPos, weight);
    //             }

    //     ///////////// Cell removal and handler functions 
    //         ///////////// removal 
    //             // to remove a row of votes from the dag.sentDagVote array, and the corresponding votes from the dag.recDagVote arrays
    //             function removeSentDagVoteCell( address voter, uint32 sdist, uint32 depth) internal {
    //                 dag.removeSentDagVoteCell( voter, sdist, depth);
    //             }

    //             // to remove a row of votes from the dag.recDagVote array, and the corresponding votes from the dag.sentDagVote arrays
    //             function removeRecDagVoteCell( address recipient, uint32 rdist, uint32 depth) public {
    //                 dag.removeRecDagVoteCell( recipient, rdist, depth);
    //             }

            
            
    //         ///////////// dist depth on opposite 
    //             function changeDistDepthFromSentCellOnOp( address voter, uint32 sdist, uint32 depth, uint32 oldSDist, uint32 oldDepth) internal {
    //                 dag.changeDistDepthFromSentCellOnOp( voter, sdist, depth, oldSDist, oldDepth);
    //             }

    //             function changeDistDepthFromRecCellOnOp( address recipient, uint32 rdist, uint32 depth, uint32 oldRDist, uint32 oldDepth) public {
    //                 dag.changeDistDepthFromRecCellOnOp( recipient, rdist, depth, oldRDist, oldDepth);
    //             }
            
    //         ///////////// move cell

    //             function moveSentDagVoteCell(address voter, uint32 sdist, uint32 depth, uint32 newSDist, uint32 newDepth) internal {
    //                 dag.moveSentDagVoteCell( voter, sdist, depth, newSDist, newDepth);
    //             }

    //             function moveRecDagVoteCell(address recipient, uint32 rdist, uint32 depth, uint32 newRDist, uint32 newDepth) internal {
    //                 dag.moveRecDagVoteCell( recipient, rdist, depth, newRDist, newDepth);
    //             }

    //     ///////////// Line  remover and sorter functions
    //         ///////////// Line removers

    //             function removeSentDagVoteLineDepthEqualsValue( address voter, uint32 value) internal {
    //                 dag.removeSentDagVoteLineDepthEqualsValue( voter, value);
    //             }

    //             function removeRecDagVoteLineDepthEqualsValue( address voter, uint32 value) internal {
    //                 dag.removeRecDagVoteLineDepthEqualsValue( voter, value);
    //             }

    //             function removeSentDagVoteLineDistEqualsValue( address voter, uint32 value) internal {
    //                 dag.removeSentDagVoteLineDistEqualsValue( voter, value);
    //             }


    //         ///////////// Sort Cell into line
    //             function sortSentDagVoteCell( address voter, uint32 sdist, uint32 depth, address anscestorAtDepth) internal {
    //                 dag.sortSentDagVoteCell( voter, sdist, depth, anscestorAtDepth); 
    //             }

    //             function sortRecDagVoteCell( address recipient, uint32 rdist, uint32 depth,  address newTreeVote) internal {
    //                 dag.sortRecDagVoteCell( recipient, rdist, depth, newTreeVote);
    //             }

    //             function sortRecDagVoteCellDescendants( address recipient, uint32 depth, address replaced) internal {
    //                 dag.sortRecDagVoteCellDescendants( recipient, depth, replaced);
    //             }
        
    //     ///////////// Area/whole triangle changers
                     
    //         ///////////// Depth and pos change across graph
    //             function increaseDistDepthFromSentOnOpFalling( address voter, uint32 diff) internal {
    //                 dag.increaseDistDepthFromSentOnOpFalling( voter, diff); 
    //             }

    //             function decreaseDistDepthFromSentOnOpRising( address voter, uint32 diff) internal {
    //                 dag.decreaseDistDepthFromSentOnOpRising( voter, diff);
    //             }

    //             function changeDistDepthFromRecOnOpFalling( address voter, uint32 diff) internal {
    //                 dag.changeDistDepthFromRecOnOpFalling( voter, diff);
    //             }

    //             function changeDistDepthFromRecOnOpRising( address voter, uint32 diff) internal {
    //                 dag.changeDistDepthFromRecOnOpRising( voter, diff);
    //             }

    //         ///////////// Movers
    //             function moveSentDagVoteUpRightFalling( address voter, uint32 diff) internal {
    //                 dag.moveSentDagVoteUpRightFalling( voter, diff);
    //             }

    //             function moveSentDagVoteDownLeftRising( address voter, uint32 diff) internal {
    //                 dag.moveSentDagVoteDownLeftRising( voter, diff);
    //             }

    //             function moveRecDagVoteUpRightFalling( address voter, uint32 diff) internal {
    //                 dag.moveRecDagVoteUpRightFalling( voter, diff);
    //             }

    //             function moveRecDagVoteDownLeftRising( address voter, uint32 diff) public {
    //                 dag.moveRecDagVoteDownLeftRising( voter, diff);
    //             }
    //         ///////////// Collapsing to, and sorting from columns

    //             function collapseSentDagVoteIntoColumn( address voter, uint32 sdistDestination) public {
    //                 dag.collapseSentDagVoteIntoColumn( voter, sdistDestination);
    //             }            

    //             function collapseRecDagVoteIntoColumn(  address voter, uint32 rdistDestination) public {
    //                 dag.collapseRecDagVoteIntoColumn( voter, rdistDestination);
    //             }

    //             function sortSentDagVoteColumn( address voter, uint32 sdist, address newTreeVote) public {
    //                 dag.sortSentDagVoteColumn( voter, sdist, newTreeVote);
    //             }

    //             function sortRecDagVoteColumn(  address recipient, uint32 rdist, address newTreeVote) public {
    //                 dag.sortRecDagVoteColumn( recipient, rdist, newTreeVote);
    //             }

    //             function sortRecDagVoteColumnDescendants(  address recipient, address replaced) public {
    //                 dag.sortRecDagVoteColumnDescendants( recipient, replaced);
    //             }

    //         ///////////// Combined dag Square vote handler for rising falling, a certain depth, with passing the new recipient in for selction    

    //             function handleDagVoteMoveRise( address voter, address recipient, address replaced, uint32 moveDist, uint32 depthToRec ) public {
    //                 dag.handleDagVoteMoveRise( voter, recipient, replaced, moveDist, depthToRec);
    //             }

    //             function handleDagVoteMoveFall( address voter, address recipient, address replaced, uint32 moveDist, uint32 depthToRec) public {
    //                 dag.handleDagVoteMoveFall( voter, recipient, replaced, moveDist, depthToRec);
    //             }



    // /////////////////////////////////////////////////////////////////////////////////////////////////////////
    // //// Global internal
        
    //     function pullUpBranch(address pulledVoter, address parent) public {
    //        dag.pullUpBranch( pulledVoter, parent);

    //     }
        
    //     function handleLeavingVoterBranch( address voter) public {
    //         dag.handleLeavingVoterBranch( voter);
    //     }

}


