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
   }
//////////

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

        }

        // when we first join the tree without a parent
        function joinTreeAsRoot(address voter, string calldata name) public {
            emit SimpleEventForUpdates("", 1);
            
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
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag externals
        // to add a vote to the dag.sentDagVote array, and also to the corresponding dag.recDagVote array
        function addDagVote(address voter, address recipient, uint32 weight) public {
            emit SimpleEventForUpdates("", 0);

            (bool votable, bool voted, uint32 sdist, uint32 depth, , ) = AnthillInner.findSentDagVote( dag , voter, recipient);
            assert ((votable) && (voted == false));

            // add DagVotes. 
            AnthillInner.combinedDagAppendSdist( dag , voter, recipient, sdist, depth, weight);    
        }

        // to remove a vote from the dag.sentDagVote array, and also from the  corresponding dag.recDagVote arrays
        function removeDagVote(address voter, address recipient) public {
            emit SimpleEventForUpdates("", 0);
            
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
            emit SimpleEventForUpdates("", 0);
            
            AnthillInner.removeSentDagVoteComplete( dag , voter);
            AnthillInner.removeRecDagVoteComplete( dag , voter);

            AnthillInner.handleLeavingVoterBranch( dag , voter);
        }

        function switchPositionWithParent(address voter) public {
            emit SimpleEventForUpdates("", 0);

            address parent = dag.treeVote[voter];
            assert (parent != address(0));
            assert (parent != address(1));
            address gparent = dag.treeVote[parent];
            
            uint256 voterRep = calculateReputation(voter);
            uint256 parentRep = calculateReputation(parent);

            assert (voterRep > parentRep);
            
            AnthillInner.handleDagVoteMoveFall( dag , parent, parent, voter, 0, 0);
            AnthillInner.handleDagVoteMoveRise( dag , voter, gparent, parent, 2, 2);
            
            AnthillInner.switchTreeVoteWithParent( dag , voter);
        }

        function moveTreeVote(address voter, address recipient) external {
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
            AnthillInner.handleLeavingVoterBranch( dag , voter);

            if ((lowerRDist == 0) && (isLowerOrEqual)){
                // if we are jumping to our descendant who just rose, we have to modify the lowerSDist
                if (  AnthillInner.findNthParent( dag , recipient, lowerDepth)==parent){
                    lowerSDist = lowerSDist - 1;
                    lowerDepth = lowerDepth - 1;
                }
            }

            // currently we don't support position swithces here, so replaced address is always 0. 
            if (isLowerOrEqual){
                AnthillInner.handleDagVoteMoveFall( dag , voter, recipient, address(0), lowerRDist, lowerDepth);
            } else if (isSimilar){
                AnthillInner.handleDagVoteMoveRise( dag , voter, recipient, address(0), simDist, simDepth);
            } else if ((isHigher) && (higherDepth > 1)){
                AnthillInner.handleDagVoteMoveRise( dag , voter, recipient, address(0), higherDist, higherDepth);
            }  else {
                // we completely jumped out. remove all dagVotes. 
                AnthillInner.removeSentDagVoteComplete( dag , voter);
                AnthillInner.removeRecDagVoteComplete( dag , voter);            
            }
            // handle tree votes
            // there is a single twise here, if recipient the descendant of the voter that rises.
            AnthillInner.addTreeVote( dag , voter, recipient);
        }


    ///////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////// imported from library
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Variable readers 
        // root/base 
            function readRoot() public view returns(address){
                return dag.readRoot();
            }

            function readMaxRelRootDepth() public view returns(uint32){
                return AnthillInner.readMaxRelRootDepth(dag);
            }

        // for node properties
            function readReputation( address voter) public view returns(uint256){
                return AnthillInner.readReputation(dag, voter);
            }

            function readName( address voter) public view returns(string memory){
                return AnthillInner.readName(dag, voter);
            }

        // for tree votes
            function readSentTreeVote( address voter) public view returns(address){
                return AnthillInner.readSentTreeVote(dag, voter);
            }

            function readRecTreeVoteCount( address recipient) public view returns(uint32){
                return AnthillInner.readRecTreeVoteCount(dag, recipient);
            }

            function readRecTreeVote( address recipient, uint32 votePos) public view returns(address){
                return AnthillInner.readRecTreeVote(dag, recipient, votePos);
            }

        // for sent dag 
            
            function readSentDagVoteDistDiff( address voter) external view returns(uint32){
                return AnthillInner.readSentDagVoteDistDiff(dag, voter);
            }

            function readSentDagVoteDepthDiff( address voter) external view returns(uint32){
                return AnthillInner.readSentDagVoteDepthDiff(dag, voter);
            }

            function readSentDagVoteCount( address voter, uint32 sdist, uint32 depth) public view returns(uint32){
                return AnthillInner.readSentDagVoteCount(dag, voter, sdist, depth);
            }

            function readSentDagVote( address voter, uint32 sdist, uint32 depth, uint32 votePos) public view returns( DagVote memory){
                return AnthillInner.readSentDagVote(dag, voter, sdist, depth, votePos);
            }

        
            function readSentDagVoteTotalWeight( address voter) public view returns( uint32){
                return AnthillInner.readSentDagVoteTotalWeight(dag, voter);
            }

        // for rec Dag votes

            function readRecDagVoteDistDiff( address recipient) external view returns(uint32){
                return AnthillInner.readRecDagVoteDistDiff(dag, recipient);
            }

            function readRecDagVoteDepthDiff( address recipient) public view returns(uint32){
                return AnthillInner.readRecDagVoteDepthDiff(dag, recipient);
            }


            function readRecDagVoteCount( address recipient, uint32 rdist, uint32 depth) public view returns(uint32){
                return AnthillInner.readRecDagVoteCount(dag, recipient, rdist, depth);
            }

            function readRecDagVote( address recipient, uint32 rdist, uint32 depth, uint32 votePos) public view returns(DagVote memory){
                return AnthillInner.readRecDagVote(dag, recipient, rdist, depth, votePos);
            }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree finder 

        function findRecTreeVotePos( address voter, address recipient) public view returns (bool voted, uint32 votePos) {
            return AnthillInner.findRecTreeVotePos(dag, voter, recipient);
        }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Personal tree internal
        function removeTreeVote(address voter) internal {
            AnthillInner.removeTreeVote(dag, voter);
        }
    
        function addTreeVote(address voter, address recipient) internal {
            AnthillInner.addTreeVote(dag, voter, recipient);
        }

        function addTreeVoteWithoutCheck(address voter, address recipient) internal {
            AnthillInner.addTreeVoteWithoutCheck(dag, voter, recipient);
        }

        // todo this needs to be cleaned up
        function switchTreeVoteWithParent(address voter) public {
            AnthillInner.switchTreeVoteWithParent(dag, voter);
        }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Local tree finders
        
        function findNthParent(address voter, uint32 height) public view returns (address parent){
            return AnthillInner.findNthParent(dag, voter, height);
        }

        // to find our relative dag.root, our ancestor at depth dag.MAX_REL_ROOT_DEPTH
        function findRelRoot( address voter) public view returns (address relRoot, uint32 relDepth){
            return AnthillInner.findRelRoot(dag, voter);
        }

        // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative dag.root
        function findRelDepth(address voter, address recipient) public view returns (bool isLocal, uint32 relDepth){
            return AnthillInner.findRelDepth(dag, voter, recipient);
        }

        // to find the distance between voter and recipient, within maxDistance. 
        // THIS IS ACTUALLY A GLOBAL FUNTION!
        function findDistAtSameDepth(address add1, address add2) public view returns (bool isSameDepth, uint32 distance) {
            return AnthillInner.findDistAtSameDepth(dag, add1, add2);
        }

        // 
        function findSDistDepth(address voter, address recipient) public view returns (bool isLocal, uint32 distance, uint32 relDepth){
            return AnthillInner.findSDistDepth(dag, voter, recipient);
        }

        

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// DAG finders
        // to check the existence and to find the position of a vote in a given row of the sentDagVote array
        function findSentDagVotePosAtDistDepth(address voter, address recipient, uint32 sdist,  uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return AnthillInner.findSentDagVotePosAtDistDepth(dag, voter, recipient, sdist, depth);
        }

        // to check the existence and to find the position of a vote in a given row of the recDagVote array
        function findRecDagVotePosAtDistDepth(address voter, address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return AnthillInner.findRecDagVotePosAtDistDepth(dag, voter, recipient, rdist, depth); 
        }

        function findLastSentDagVoteAtDistDepth(address voter, uint32 sdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return AnthillInner.findLastSentDagVoteAtDistDepth(dag, voter, sdist, depth);
        }

        function findLastRecDagVoteAtDistDepth(address recipient, uint32 rdist, uint32 depth) public view returns (bool voted, uint32 votePos, DagVote memory vote){
            return AnthillInner.findLastRecDagVoteAtDistDepth(dag, recipient, rdist, depth);
        }

        // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
        function findSentDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 sdist,  uint32 depth, uint32 votePos, DagVote memory dagVote){ 
            return AnthillInner.findSentDagVote(dag, voter, recipient);
        }

        // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position (first index), votePos is column pos (second index))
        function findRecDagVote(address voter, address recipient) public view returns (bool votable, bool voted, uint32 rdist, uint32 depth, uint32 votePos, DagVote memory dagVote){
            return AnthillInner.findRecDagVote(dag, voter, recipient);
        }



    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Dag internals. Core logic. 
        ///////////// Single vote changes
            ///////////// appending a vote

                function sentDagAppend( address voter, uint32 sdist, uint32 depth, address recipient, uint32 weight, uint32 rPos ) internal{
                    return AnthillInner.sentDagAppend(dag, voter, sdist, depth, recipient, weight, rPos);
                }

                function recDagAppend( address recipient, uint32 rdist, uint32 depth, address voter, uint32 weight, uint32 sPos ) public{
                    return AnthillInner.recDagAppend(dag, recipient, rdist, depth, voter, weight, sPos);   
                }

                function combinedDagAppendSdist( address voter, address recipient,  uint32 sdist, uint32 depth, uint32 weight) internal{
                    return AnthillInner.combinedDagAppendSdist(dag, voter, recipient, sdist, depth, weight);   
                }

            ///////////// changing position

                function changePositionSent( address voter, uint32 sdist,  uint32 depth, uint32 sPos, uint32 newRPos) internal {
                    return AnthillInner.changePositionSent(dag, voter, sdist, depth, sPos, newRPos);
                }

                function changePositionRec( address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newSPos) internal{
                    return AnthillInner.changePositionRec(dag, recipient, rdist, depth, rPos, newSPos);
                }   

            

            ///////////// delete and removal functions
                ///// we never just delete a vote, as that would leave a gap in the array. We only delete the last vote, or we remove multiple votes.
                
                /// careful, does not delete the opposite or deacrese count! Do not call, call unsafeReplace..  or safeRemove.. instead
                function unsafeDeleteLastSentDagVoteAtDistDepth( address voter, uint32 sdist, uint32 depth) internal {
                    delete dag.sentDagVote[voter][dag.sentDagVoteDistDiff[voter]+ sdist][dag.sentDagVoteDepthDiff[voter]+depth][AnthillInner.readSentDagVoteCount(dag, voter, sdist, depth)-1];
                }

                /// careful, does not delete the opposite, or decrease count! Do not call, call unsafeReplace..  or safeRemove.. instead
                function unsafeDeleteLastRecDagVoteAtDistDepth( address recipient, uint32 rdist, uint32 depth) internal {
                    delete dag.recDagVote[recipient][dag.recDagVoteDistDiff[recipient]+ rdist][dag.recDagVoteDepthDiff[recipient]+depth][AnthillInner.readRecDagVoteCount(dag, recipient, rdist, depth)-1];
                }   

                // careful does not delete the opposite! Always call with opposite, or do something with the other vote
                function unsafeReplaceSentDagVoteAtDistDepthPosWithLast( address voter, uint32 sdist, uint32 depth, uint32 sPos) internal {
                    AnthillInner.unsafeReplaceSentDagVoteAtDistDepthPosWithLast(dag, voter, sdist, depth, sPos);
                } 

                /// careful, does not delete the opposite!
                function unsafeReplaceRecDagVoteAtDistDepthPosWithLast( address recipient, uint32 rdist, uint32 depth, uint32 rPos) public {
                    AnthillInner.unsafeReplaceRecDagVoteAtDistDepthPosWithLast(dag, recipient, rdist, depth, rPos);
                } 

                function safeRemoveSentDagVoteAtDistDepthPos(address voter, uint32 sdist, uint32 depth, uint32 sPos) internal {
                    AnthillInner.safeRemoveSentDagVoteAtDistDepthPos(dag, voter, sdist, depth, sPos);    
                }

                function safeRemoveRecDagVoteAtDistDepthPos( address recipient, uint32 rdist, uint32 depth, uint32 rPos) internal {
                    AnthillInner.safeRemoveRecDagVoteAtDistDepthPos(dag, recipient, rdist, depth, rPos);
                }

            ///////////// change dist and depth
                function changeDistDepthSent( address voter, uint32 sdist, uint32 depth, uint32 sPos, uint32 newSDist, uint32 newDepth, address recipient, uint32 rPos, uint32 weight) public{
                    // here it is ok to use unsafe, as the the vote is moved, not removed
                   AnthillInner.changeDistDepthSent(dag, voter, sdist, depth, sPos, newSDist, newDepth, recipient, rPos, weight);
                }

                function changeDistDepthRec( address recipient, uint32 rdist, uint32 depth, uint32 rPos, uint32 newRDist, uint32 newDepth, address voter, uint32 sPos, uint32 weight) public{
                    // here it is ok to use unsafe, as the the vote is moved, not removed
                    AnthillInner.changeDistDepthRec(dag, recipient, rdist, depth, rPos, newRDist, newDepth, voter, sPos, weight);
                }

        ///////////// Cell removal and handler functions 
            ///////////// removal 
                // to remove a row of votes from the dag.sentDagVote array, and the corresponding votes from the dag.recDagVote arrays
                function removeSentDagVoteCell( address voter, uint32 sdist, uint32 depth) internal {
                    AnthillInner.removeSentDagVoteCell(dag, voter, sdist, depth);
                }

                // to remove a row of votes from the dag.recDagVote array, and the corresponding votes from the dag.sentDagVote arrays
                function removeRecDagVoteCell( address recipient, uint32 rdist, uint32 depth) public {
                    AnthillInner.removeRecDagVoteCell(dag, recipient, rdist, depth);
                }

            
            
            ///////////// dist depth on opposite 
                function changeDistDepthFromSentCellOnOp( address voter, uint32 sdist, uint32 depth, uint32 oldSDist, uint32 oldDepth) internal {
                    AnthillInner.changeDistDepthFromSentCellOnOp(dag, voter, sdist, depth, oldSDist, oldDepth);
                }

                function changeDistDepthFromRecCellOnOp( address recipient, uint32 rdist, uint32 depth, uint32 oldRDist, uint32 oldDepth) public {
                    AnthillInner.changeDistDepthFromRecCellOnOp(dag, recipient, rdist, depth, oldRDist, oldDepth);
                }
            
            ///////////// move cell

                function moveSentDagVoteCell(address voter, uint32 sdist, uint32 depth, uint32 newSDist, uint32 newDepth) internal {
                    AnthillInner.moveSentDagVoteCell(dag, voter, sdist, depth, newSDist, newDepth);
                }

                function moveRecDagVoteCell(address recipient, uint32 rdist, uint32 depth, uint32 newRDist, uint32 newDepth) internal {
                    AnthillInner.moveRecDagVoteCell(dag, recipient, rdist, depth, newRDist, newDepth);
                }

        ///////////// Line  remover and sorter functions
            ///////////// Line removers

                function removeSentDagVoteLineDepthEqualsValue( address voter, uint32 value) internal {
                    AnthillInner.removeSentDagVoteLineDepthEqualsValue(dag, voter, value);
                }

                function removeRecDagVoteLineDepthEqualsValue( address voter, uint32 value) internal {
                    AnthillInner.removeRecDagVoteLineDepthEqualsValue(dag, voter, value);
                }

                function removeSentDagVoteLineDistEqualsValue( address voter, uint32 value) internal {
                    AnthillInner.removeSentDagVoteLineDistEqualsValue(dag, voter, value);
                }


            ///////////// Sort Cell into line
                function sortSentDagVoteCell( address voter, uint32 sdist, uint32 depth, address anscestorAtDepth) internal {
                    AnthillInner.sortSentDagVoteCell(dag, voter, sdist, depth, anscestorAtDepth); 
                }

                function sortRecDagVoteCell( address recipient, uint32 rdist, uint32 depth,  address newTreeVote) internal {
                    AnthillInner.sortRecDagVoteCell(dag, recipient, rdist, depth, newTreeVote);
                }

                function sortRecDagVoteCellDescendants( address recipient, uint32 depth, address replaced) internal {
                    AnthillInner.sortRecDagVoteCellDescendants(dag, recipient, depth, replaced);
                }
        
        ///////////// Area/whole triangle changers
                     
            ///////////// Depth and pos change across graph
                function increaseDistDepthFromSentOnOpFalling( address voter, uint32 diff) internal {
                    AnthillInner.increaseDistDepthFromSentOnOpFalling(dag, voter, diff); 
                }

                function decreaseDistDepthFromSentOnOpRising( address voter, uint32 diff) internal {
                    AnthillInner.decreaseDistDepthFromSentOnOpRising(dag, voter, diff);
                }

                function changeDistDepthFromRecOnOpFalling( address voter, uint32 diff) internal {
                    AnthillInner.changeDistDepthFromRecOnOpFalling(dag, voter, diff);
                }

                function changeDistDepthFromRecOnOpRising( address voter, uint32 diff) internal {
                    AnthillInner.changeDistDepthFromRecOnOpRising(dag, voter, diff);
                }

            ///////////// Movers
                function moveSentDagVoteUpRightFalling( address voter, uint32 diff) internal {
                    AnthillInner.moveSentDagVoteUpRightFalling(dag, voter, diff);
                }

                function moveSentDagVoteDownLeftRising( address voter, uint32 diff) internal {
                    AnthillInner.moveSentDagVoteDownLeftRising(dag, voter, diff);
                }

                function moveRecDagVoteUpRightFalling( address voter, uint32 diff) internal {
                    AnthillInner.moveRecDagVoteUpRightFalling(dag, voter, diff);
                }

                function moveRecDagVoteDownLeftRising( address voter, uint32 diff) public {
                    AnthillInner.moveRecDagVoteDownLeftRising(dag, voter, diff);
                }
            ///////////// Collapsing to, and sorting from columns

                function collapseSentDagVoteIntoColumn( address voter, uint32 sdistDestination) public {
                    AnthillInner.collapseSentDagVoteIntoColumn(dag, voter, sdistDestination);
                }            

                function collapseRecDagVoteIntoColumn(  address voter, uint32 rdistDestination) public {
                    AnthillInner.collapseRecDagVoteIntoColumn(dag, voter, rdistDestination);
                }

                function sortSentDagVoteColumn( address voter, uint32 sdist, address newTreeVote) public {
                    AnthillInner.sortSentDagVoteColumn(dag, voter, sdist, newTreeVote);
                }

                function sortRecDagVoteColumn(  address recipient, uint32 rdist, address newTreeVote) public {
                    AnthillInner.sortRecDagVoteColumn(dag, recipient, rdist, newTreeVote);
                }

                function sortRecDagVoteColumnDescendants(  address recipient, address replaced) public {
                    AnthillInner.sortRecDagVoteColumnDescendants(dag, recipient, replaced);
                }

            ///////////// Combined dag Square vote handler for rising falling, a certain depth, with passing the new recipient in for selction    

                function handleDagVoteMoveRise( address voter, address recipient, address replaced, uint32 moveDist, uint32 depthToRec ) public {
                    AnthillInner.handleDagVoteMoveRise(dag, voter, recipient, replaced, moveDist, depthToRec);
                }

                function handleDagVoteMoveFall( address voter, address recipient, address replaced, uint32 moveDist, uint32 depthToRec) public {
                    AnthillInner.handleDagVoteMoveFall(dag, voter, recipient, replaced, moveDist, depthToRec);
                }



    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// Global internal
        
        function pullUpBranch(address pulledVoter, address parent) public {
           AnthillInner.pullUpBranch(dag, pulledVoter, parent);

        }
        
        function handleLeavingVoterBranch( address voter) public {
            AnthillInner.handleLeavingVoterBranch(dag, voter);
        }

}

library AnthillInner{
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

        // todo this needs to be cleaned up
        function switchTreeVoteWithParent(Dag storage dag,address voter) public {
            address parent = dag.treeVote[voter];
            assert (parent != address(0));
            assert (parent != address(1));
            
            address gparent = dag.treeVote[parent]; // this might be 1. 
            removeTreeVote( dag , voter);

            if (readRoot( dag  )== parent){
                dag.root= voter;
            } else {
                removeTreeVote( dag , parent);
            }

            addTreeVoteWithoutCheck( dag , voter, gparent);
            addTreeVoteWithoutCheck( dag , parent, voter);

            for (uint32 i = 0; i < dag.recTreeVoteCount[parent]; i++) {
                address brother = dag.recTreeVote[parent][i];
                if (brother != voter) {
                    removeTreeVote( dag , brother);
                    addTreeVoteWithoutCheck( dag , brother, voter);
                }
            }
            // how do we know that we are not moving the recipient back to the parent? 
            for (uint32 i = 0; i < dag.recTreeVoteCount[voter]; i++) {
                address child = dag.recTreeVote[voter][i];
                removeTreeVote( dag , child);
                addTreeVoteWithoutCheck( dag , child, parent);
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
    //// Dag publics. Core logic. 
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
                    removeRecDagVoteBelowDepthInclusive( dag , voter, dag.MAX_REL_ROOT_DEPTH - moveDist + 1);
                    removeRecDagVoteAboveDepthInclusive( dag , voter, depthToRec +1);         
            
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
