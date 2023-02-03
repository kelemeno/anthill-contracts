// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import  "../src/Anthill.sol";
import {DagVote, Dag} from "../src/Anthill.sol";
import {console} from "forge-std/console.sol";

// for testing uncomment modifiers, and comment msg.sender checks out
// until then test are also commented out. 

contract AnthillTestMain is Test {
    Anthill public anthill;

    function setUp() public {
        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));

        // adding tree votes. For the numbering we are adding children for i, j voter. 
        for (uint256 depth=1 ; depth<5; depth++){
            for (uint256 verticalNum=0; verticalNum<2**(depth-1); verticalNum++){
                anthill.joinTree(address(uint160(2*(2**depth+verticalNum))), string("Name"),address(uint160(2**depth+verticalNum)));
                anthill.joinTree(address(uint160(2*(2**depth+verticalNum)+1)), string("Name"),address(uint160(2**depth+verticalNum)));
            }
        }

        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));
        
        for (uint256 depth=1 ; depth<=5; depth++){
            for (uint256 verticalNum=0; verticalNum<2**(depth-1); verticalNum++){
                for (uint256 recDepth=1; recDepth<depth; recDepth++){      
                    // we want 2 to receive less, and the second lowest layer to receive more votes. 
                    uint32 weight =1000;
                    if (recDepth == 1){
                        weight = 1;
                    } else if (recDepth == 4){
                        weight = 100000;
                    } 

                    for ( uint256 recVerticalNum=0; recVerticalNum<2**(recDepth-1); recVerticalNum++){
                        
                        // we cannot add votes between parents and children, as we already added those votes in joinTree
                        if (2**depth+verticalNum >= 2*(2**recDepth+recVerticalNum)  ){
                            if (2**depth+verticalNum-2*(2**recDepth+recVerticalNum) ==0 ) continue;
                            if (2**depth+verticalNum-2*(2**recDepth+recVerticalNum) ==1 ) continue;
                        }
                        anthill.addDagVote(address(uint160(2**depth+verticalNum)), address(uint160(2**recDepth+recVerticalNum)), weight);
                    }
                }                
            }
        }      
    }
    

    // /////////////////////////////////////////////
    // /////////// personal and local checks
    //     function testRelDepth() public {
    //         (bool isLocal, uint32 depth ) = anthill.findRelDepth(address(4), address(5));
    //         assertEq(depth, 0);
    //         assert(isLocal);
    //     }

    //     function testReadRoot() public {
    //         address a = anthill.readRoot();
    //         assertEq(a, address(2));
    //     }

    //     function testParents() public {
    //         address a = anthill.readSentTreeVote( anthill.readSentTreeVote( anthill.readSentTreeVote(address(23))));
    //         assertEq(a, address(2));
    //     }

    //     function testFindRelDepth() public {
    //         (, uint32 depth ) = anthill.findRelDepth(address(8), address(5));
    //         assertEq(depth, 1);
    //     }

    //     function testFindNthParent() public {
    //         (address voteA ) = anthill.findNthParent(address(8),1);
    //         assertEq(voteA, address(4));
    //     }

    //     function testFindDistAtSameDepth() public {
    //         (bool isLocal, uint32 dist ) = anthill.findDistAtSameDepth(address(4),address(5));
    //         assertEq(1, dist);
    //         assert(isLocal);
    //     }

    // /////////////////////////////////////////////
    // /////////// basic dag tests
    //     function testFindSentDagVote() public {
    //         (, bool voted, uint32 dist, uint32 depth, uint32 votePos, ) = anthill.findSentDagVote(address(8),address(5));
    //         assertEq(votePos, 0);
    //         assertEq(dist, 2);
    //         assertEq(depth, 1);
    //         assertEq(voted, true);

    //     }

    //     function testAddAndRemoveDagVote1() public {
    //         anthill.removeDagVote(address(8),address(5));
    //         anthill.addDagVote(address(8),address(5), 1);
    //         (, bool voted, uint32 dist, uint32 depth, , ) = anthill.findSentDagVote(address(8), address(5));
    //         assertEq(voted, true);
    //         assertEq(dist, 2);
    //         assertEq(depth, 1);

    //         (, voted,  dist,  depth, , ) = anthill.findRecDagVote(address(8), address(5));
    //         assertEq(voted, true);
    //         assertEq(dist, 1);
    //         assertEq(depth, 1);

    //         anthill.removeDagVote(address(8),address(5));
    //         (,  voted,  dist,  depth, , ) = anthill.findSentDagVote(address(8), address(5));
    //         assertEq(voted, false);

    //         (,  voted,  dist,  depth, , ) = anthill.findRecDagVote(address(8), address(5));
    //         assertEq(voted, false);

    //     }

    //     function testAddAndRemoveDagVote2() public {
    //         // anthill.addDagVote(address(34),address(9), 1);
    //         (, bool voted, uint32 dist, uint32 depth, , ) = anthill.findSentDagVote(address(34), address(9));
    //         assertEq(voted, true);
    //         assertEq(dist, 3);
    //         assertEq(depth, 2);

    //         (, voted,  dist,  depth, , ) = anthill.findRecDagVote(address(34), address(9));
    //         assertEq(voted, true);
    //         assertEq(dist, 1);
    //         assertEq(depth, 2);

    //         anthill.removeDagVote(address(34),address(9));
    //         (,  voted,  dist,  depth, , ) = anthill.findSentDagVote(address(34), address(9));
    //         assertEq(voted, false);

    //         ( , voted,  dist,  depth, , ) = anthill.findRecDagVote(address(34), address(9));
    //         assertEq(voted, false);

    //     }

    // /////////////////////////////////////////////
    // ////////// Dag internal tests
    //     /////////////////////////////////////////
    //     /////////// single votes
    //         function testChangeDistDepthRec() public {
    //             (, bool voted, uint32 rdist, uint32 depth, uint32 votePos, DagVote memory rDagVote) = anthill.findRecDagVote(address(16), address(4));
    //             assertEq(voted, true);
    //             assertEq(rdist, 0);
    //             assertEq(depth, 2);
    //             assertEq(votePos, 0);

    //             anthill.unsafeReplaceRecDagVoteAtDistDepthPosWithLast(address(4), 0, 2, 0);

    //             uint32 count = anthill.readRecDagVoteCount(address(4), 0, 2);
    //             assertEq(count, 3); 
    //             count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //             assertEq(count, 4);

    //             anthill.recDagAppend(address(4), 1, 2, address(16), rDagVote.weight, anthill.readSentDagVoteCount(address(16), 3, 2));
    //             count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //             assertEq(count, 5);

    //             count = anthill.readSentDagVoteCount(address(16), 3, 2);
    //             assertEq(count, 1);

    //             anthill.changeDistDepthSent(address(16), 2, 2, rDagVote.posInOther, 3, 2, address(4), anthill.readRecDagVoteCount(address(4), 1, 2)-1, rDagVote.weight);
    //             count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //             assertEq(count, 5);
    //             count = anthill.readSentDagVoteCount(address(16), 3, 2);
    //             assertEq(count, 2);
    //             count = anthill.readSentDagVoteCount(address(16), 2, 2);
    //             assertEq(count, 0);
    //             intermediateDagConsistencyCheckFrom(address(2));
    //         }

    //     ////////////////////////////////////////
    //     /////////// cells


    //         // function testMergeCell() public{
            
    //         //     uint32 count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 4); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 2);
    //         //     assertEq(count, 4); 
            
    //         //     anthill.mergeRecDagVoteDiagonalCell(address(4), 2);
            
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 0); 

    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 2);
    //         //     assertEq(count, 8); 

    //         //     // anthill.changeDistDepthFromRecCellOnOp(address(4), 3, depth, oldDist, oldDepth);
    //         //     intermediateConsistencyCheckFrom(address(2));
    //         // }

    //         // function testMerge() public{
    //         //     uint256 count = anthill.readRecDagVoteCount(address(4), 1, 1);
    //         //     assertEq(count, 2); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 4);
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 3);
    //         //     assertEq(count, 8);
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 1);
    //         //     assertEq(count, 2); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 2);
    //         //     assertEq(count, 4);
    //         //     count = anthill.readRecDagVoteCount(address(4), 4, 3);
    //         //     assertEq(count, 8);

    //         //     anthill.mergeRecDagVoteDiagonal(address(4));
                
    //         //     count = anthill.readRecDagVoteCount(address(4), 1, 1);
    //         //     assertEq(count, 0); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 0);
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 3);
    //         //     assertEq(count, 0);
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 1);
    //         //     assertEq(count, 4); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 2);
    //         //     assertEq(count, 8);
    //         //     count = anthill.readRecDagVoteCount(address(4), 4, 3);
    //         //     assertEq(count, 16);

    //         //     intermediateConsistencyCheckFrom(address(2));

    //         // }
        
    //         // function testSplitCell() public{
    //         //     uint32 count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 4); 
    //         //     anthill.splitRecDagVoteDiagonalCell(address(4), 2, address(8));
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 2); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //         //     assertEq(count, 2); 
    //         //     intermediateConsistencyCheckFrom(address(2));
    //         // }

    //         // function testSplit() public {
    //         //     // uint256 count = anthill.readRecDagVoteCount(address(4), 1, 1);
    //         //     // assertEq(count, 2); 
    //         //     uint256 count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 4);
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 3);
    //         //     assertEq(count, 8);
    //         //     // count = anthill.readRecDagVoteCount(address(4), 2, 1);
    //         //     // assertEq(count, 2); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //         //     assertEq(count, 0);
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 3);
    //         //     assertEq(count, 0);

    //         //     anthill.splitRecDagVoteDiagonal(address(4), address(8));
                
    //         //     // count = anthill.readRecDagVoteCount(address(4), 1, 1);
    //         //     // assertEq(count, 2); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 2);
    //         //     assertEq(count, 2);
    //         //     count = anthill.readRecDagVoteCount(address(4), 3, 3);
    //         //     assertEq(count, 4);
    //         //     // count = anthill.readRecDagVoteCount(address(4), 2, 1);
    //         //     // assertEq(count, 4); 
    //         //     count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //         //     assertEq(count, 2);
    //         //     count = anthill.readRecDagVoteCount(address(4), 2, 3);
    //         //     assertEq(count, 4);

    //         //     intermediateConsistencyCheckFrom(address(2));
    //         // }

    //         function testChangeDistDepthFromRecCellOnOp() public {
    //             // first we clear a cell
    //             uint32 count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //             assertEq(count, 4);
    //             anthill.removeRecDagVoteCell(address(4), 1, 2);
    //             count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //             assertEq(count, 0);

    //             // then we move a cell to it
    //             count = anthill.readRecDagVoteCount(address(4), 0, 2);
    //             assertEq(count, 4);

    //             for (uint32 i = 0; i < anthill.readRecDagVoteCount(address(4), 0, 2); i++){
    //                 DagVote memory rDagVote = anthill.readRecDagVote(address(4), 0, 2, i);
    //                 anthill.recDagAppend(address(4), 1, 2, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
    //             }

    //             count = anthill.readRecDagVoteCount(address(4), 1, 2);
    //             assertEq(count, 4);

    //             // remove the moved cell
    //             for (uint32 i = anthill.readRecDagVoteCount(address(4), 0, 2)  ; i >= 1; i--){
    //                 anthill.unsafeReplaceRecDagVoteAtDistDepthPosWithLast(address(4), 0, 2, i-1);      
    //             }

    //             count = anthill.readRecDagVoteCount(address(4), 0, 2);
    //             assertEq(count, 0);
    //             anthill.changeDistDepthFromRecCellOnOp(address(4), 1, 2, 0, 2);
    //             intermediateDagConsistencyCheckFrom(address(2));
    //         }
    //     /////////////////////////////////////////
    //     /////////// collapse and sort

    //         function testCollapseSortSent() public {
    //             anthill.collapseSentDagVoteIntoColumn(address(32), 3);
    //             anthill.sortSentDagVoteColumn(address(32), 3, address(16));
    //             // intermediateDagConsistencyCheckFrom(address(2));
    //             dagConsistencyCheckFrom(address(2));
    //         }

    //         function testCollapseSortRec() public {
    //             anthill.collapseRecDagVoteIntoColumn(address(8), 2);

    //             (bool voted, uint32 votepos, DagVote memory rDagVote) = anthill.findRecDagVotePosAtDistDepth(address(18), address(8), 2, 1);
    //             assert (voted);
    //             (bool svoted, uint32 svotepos, DagVote memory sDagVote) =anthill.findSentDagVotePosAtDistDepth(address(18), address(8), 3, 1 );
    //             assert (svoted);
    //             assertEq(svotepos ,  rDagVote.posInOther);
    //             assertEq(votepos , sDagVote.posInOther);
                
    //             // we should not need to rise, we are staying in the same place
    //             anthill.sortRecDagVoteColumn(address(8), 2, address(4));
    //             anthill.sortRecDagVoteColumnDescendants(address(8), (address(8)));
    //             // printRecDagVotes(address(8));

    //             (voted,  votepos, rDagVote) = anthill.findRecDagVotePosAtDistDepth(address(18), address(8), 1, 1);
    //             assert (voted);
    //             ( svoted,  svotepos,  sDagVote) =anthill.findSentDagVotePosAtDistDepth(address(18), address(8), 2, 1 );
    //             assert (svoted);
    //             assertEq(svotepos,  rDagVote.posInOther);
    //             assertEq(votepos, sDagVote.posInOther);

    //             // intermediateDagConsistencyCheckFrom(address(2));
    //             dagConsistencyCheckFrom(address(2));
    //         }

    //     ////////////////////////////////////////
    //     /////////// combined square handlers

    //         function testHandleDagVoteMoveRise() public {
    //             anthill.handleDagVoteMoveRise(address(4), address(1), address(2), 2, 2);
    //             // printRecDagVotes(address(2));
    //             // read rec and sent votes from 8, 20, 5

    //             // (bool voted2, uint32 votePos2, DagVote memory rDagVote) = anthill.findRecDagVotePosAtDistDepth(address(8), address(4), 0, 2);
    //             // assert (voted2);
    //             // console.log("votePos: ", votePos);
    //             // console.log("dagVote: ",sDagVote.id, sDagVote.posInOther);
    //             // printRecDagVotes(address(4));

    //             intermediateDagConsistencyCheckFrom(address(2));
    //         }

    // ///////////////////////////////////////////
    // /////////// E2E tests 

    //     // function testCalculateRep() public {
    //         //     uint256 rep = anthill.calculateReputation(address(4));
    //         //     uint256 rep2 = anthill.calculateReputation(address(2));
    //         //     console.log(rep);
    //         //     console.log(rep2);

    //         //     assert(rep  +100- 3000000000000000000< 1000);
    //         //     assert(rep2 +100- 1000000000000000000< 1000);

    //     // }

    //     function testSwitchPositionWithParent1() public {
    //         address root = anthill.readRoot();
    //         assertEq(root, address(2));
            
    //         anthill.switchPositionWithParent(address(4));
    //         root = anthill.readRoot();
    //         assertEq(root, address(4));

    //         assert(anthill.readSentTreeVote(address(16))==address(8));
    //         assert(anthill.readSentTreeVote(address(8))==address(2));
    //         assert(anthill.readSentTreeVote(address(2))==address(4));
    //         assert(anthill.readSentTreeVote(address(10))==address(5));
    //         assert(anthill.readSentTreeVote(address(5))==address(4));

    //         // intermediateDagConsistencyCheckFrom(address(2));
    //         dagConsistencyCheckFrom(address(4));
    //         treeConsistencyCheckFrom(address(4));
    //     }

    //     function testSwitchPositionWithParent2() public {
    //         // todo
    //         for (uint160 i = 32; i< 48; i++){
    //             anthill.removeDagVote(address(i), address(16));
    //         }
    //         anthill.moveTreeVote(address(33), address(32));
    //         anthill.addDagVote(address(33), address(32), 100000000);
    //         anthill.switchPositionWithParent(address(32));
    //         (address parent) = anthill.readSentTreeVote(address(16));
    //         assertEq(parent, address(32));
    //         dagConsistencyCheckFrom(address(2));
    //         treeConsistencyCheckFrom(address(2));

    //     }

    //     function testLeaveTree() public {
            
    //         anthill.leaveTree(address(4));

    //         // for 2
    //         address recipient = anthill.readRecTreeVote(address(2), 0);
    //         assertEq(recipient, address(8));

    //         recipient = anthill.readRecTreeVote(address(2), 1);
    //         assertEq(recipient, address(5));
            
    //         recipient = anthill.readSentTreeVote(address(8));
    //         assertEq(recipient, address(2));

    //         // for 8

    //         recipient = anthill.readRecTreeVote(address(8), 0);
    //         assertEq(recipient, address(16));

    //         recipient = anthill.readRecTreeVote(address(8), 1);
    //         assertEq(recipient, address(9));

    //         recipient = anthill.readSentTreeVote(address(9));
    //         assertEq(recipient, address(8));

    //         recipient = anthill.readSentTreeVote(address(16));
    //         assertEq(recipient, address(8));

    //         // for 16

    //         recipient = anthill.readRecTreeVote(address(16), 0);
    //         assertEq(recipient, address(32));

    //         recipient = anthill.readRecTreeVote(address(16), 1);
    //         assertEq(recipient, address(17));

    //         recipient = anthill.readSentTreeVote(address(17));
    //         assertEq(recipient, address(16));

    //         recipient = anthill.readSentTreeVote(address(32));
    //         assertEq(recipient, address(16));

    //         // // for 32

    //         recipient = anthill.readRecTreeVote(address(32), 0);
    //         assertEq(recipient, address(33));

    //         recipient = anthill.readRecTreeVote(address(32), 1);
    //         assertEq(recipient, address(0));

    //         recipient = anthill.readSentTreeVote(address(33));
    //         assertEq(recipient, address(32));

    //         dagConsistencyCheckFrom(address(2));
    //         treeConsistencyCheckFrom(address(2));
    //     }

    //     function testMoveInTree1() public {
    //         anthill.moveTreeVote(address(16), address(32));
    //         dagConsistencyCheckFrom(address(2));
    //         treeConsistencyCheckFrom(address(2));
    //     }

    //     function testMoveInTree2() public {
    //         anthill.moveTreeVote(address(16), address(40));
    //         dagConsistencyCheckFrom(address(2));
    //         treeConsistencyCheckFrom(address(2));
    //     }

    //     function testMoveInTree3() public {
    //         anthill.moveTreeVote(address(32), address(40));
    //         anthill.moveTreeVote(address(32), address(16));
    //         dagConsistencyCheckFrom(address(2));
    //         treeConsistencyCheckFrom(address(2));
    //     }

    //     function testConsistecy() public {
    //         treeConsistencyCheckFrom(address(2));
    //         dagConsistencyCheckFrom(address(2));
    //     }

    // //////////////////////////////////////////
    // ///////////// utils 

        function treeConsistencyCheckFrom(address voter) public {
            for (uint32 i = 0; i < anthill.readRecTreeVoteCount(voter); i++){
                address recipient = anthill.readRecTreeVote(voter, i);
                if (recipient != address(0)){
                    address sender = anthill.readSentTreeVote(recipient);
                    assertEq(sender, voter);
                    treeConsistencyCheckFrom(recipient);
                }
            }
        }

        function intermediateDagConsistencyCheckFrom(address voter) public {

            for (uint32 dist = 0; dist < 7; dist++){
                for (uint32 depth = 1; depth <= dist; depth++){
                    for (uint32 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++){
                        DagVote memory sDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                        DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, dist-depth, depth, sDagVote.posInOther);
                        (bool isLocal, ,) = anthill.findSDistDepth(voter, sDagVote.id);
                        assert( isLocal);
                        // console.log("id", voter, rDagVote.id, sDagVote.id);
                        assertEq(rDagVote.id, voter);
                        assertEq(rDagVote.weight, sDagVote.weight);
                        assertEq(rDagVote.posInOther, i);

                        
                    }

                    for (uint32 i = 0; i < anthill.readRecDagVoteCount(voter, dist-depth, depth); i++){
                        DagVote memory rDagVote = anthill.readRecDagVote(voter, dist-depth, depth, i);
                        DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, dist, depth, rDagVote.posInOther);

                        (bool isLocal, ,) = anthill.findSDistDepth(rDagVote.id, voter);
                        assert( isLocal);
                        
                        // console.log("voter: ", voter);
                        // console.log( dist, depth, i, rDagVote.id);
                        assertEq(sDagVote.id, voter);
                        assertEq(sDagVote.weight, rDagVote.weight);
                        assertEq(sDagVote.posInOther, i);
                    }
                }
            }
            for (uint32 i=0; i< anthill.readRecTreeVoteCount(voter); i++){
                intermediateDagConsistencyCheckFrom(anthill.readRecTreeVote(voter, i));
            } 
        }

        function dagConsistencyCheckFrom(address voter) public {

            for (uint32 dist = 0; dist < 7; dist++){
                for (uint32 depth = 0; depth <= dist; depth++){
                    for (uint32 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++){
                        DagVote memory sDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                        DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, dist-depth, depth, sDagVote.posInOther);
                        (bool isLocal, uint32 recordedDist, uint32 recordedDepth) = anthill.findSDistDepth(voter, sDagVote.id);
                        assert( isLocal);
                        // console.log("id", voter, rDagVote.id, sDagVote.id);
                        assertEq(rDagVote.id, voter);
                        assertEq(rDagVote.weight, sDagVote.weight);
                        assertEq(rDagVote.posInOther, i);

                        assertEq(recordedDist, dist);
                        assertEq(recordedDepth, depth);
                    }

                    for (uint32 i = 0; i < anthill.readRecDagVoteCount(voter, dist-depth, depth); i++){
                        DagVote memory rDagVote = anthill.readRecDagVote(voter, dist-depth, depth, i);
                        DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, dist, depth, rDagVote.posInOther);

                        (bool isLocal, uint32 recordedDist, uint32 recordedDepth) = anthill.findSDistDepth(rDagVote.id, voter);
                        assert( isLocal);
                        
                        // console.log("voter: ", voter, recordedDist, dist);
                        // console.log( dist, depth, i, rDagVote.id);
                        assertEq(sDagVote.id, voter);
                        assertEq(sDagVote.weight, rDagVote.weight);
                        assertEq(sDagVote.posInOther, i);

                        assertEq(recordedDist, dist);
                        assertEq(recordedDepth, depth);
                    }
                }
            }
            for (uint32 i=0; i< anthill.readRecTreeVoteCount(voter); i++){
                dagConsistencyCheckFrom(anthill.readRecTreeVote(voter, i));
            } 
        }

        function printRecDagVotes(address voter) public view {
            for (uint32 dist = 0; dist < 7; dist++){
                for (uint32 depth = 0; depth <= 7; depth++){
                    for (uint32 i = 0; i < anthill.readRecDagVoteCount(voter, dist, depth); i++){
                        DagVote memory rDagVote = anthill.readRecDagVote(voter, dist, depth, i);
                        console.log("rec dag vote: ", voter, dist, depth);
                        console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
                    }
                }
            }
        }

        function printSentDagVotes(address voter) public view {
            for (uint32 dist = 0; dist < 7; dist++){
                for (uint32 depth = 0; depth <= 7; depth++){
                    for (uint32 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++){
                        DagVote memory rDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                        console.log("sent dag vote: ", voter, dist, depth);
                        console.log(i, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
                    }
                }
            }
            console.log("rec dag votes finished");
        }

    
}

