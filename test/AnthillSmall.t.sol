// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import  "../src/Anthill.sol";
import {DagVote, Dag} from "../src/Anthill.sol";
import {console} from "forge-std/console.sol";

// for testing uncomment modifiers
// until then test are also commented out. 


contract AnthillTestSmall is Test {
    Anthill public anthill;

    function setUp() public {
        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("2"));

        // adding tree votes. For the numbering we are adding children for i, j voter. 
       
        anthill.joinTree(address(4), string("4"),address(2));
        anthill.joinTree(address(5), string("5"),address(2));

        anthill.joinTree(address(8), string("8"),address(4));

        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));
        anthill.addDagVote(address(8), address(5), 1);
        
      
    }
           

    function testSwitchPositionWithParent3() public {
        address root = anthill.readRoot();
        assertEq(root, address(2));
        
        anthill.switchPositionWithParent(address(5));
        root = anthill.readRoot();
        assertEq(root, address(5));

        assert(anthill.readSentTreeVote(address(2))==address(5));
        assert(anthill.readSentTreeVote(address(4))==address(5));

        dagConsistencyCheckFrom(address(5));
        treeConsistencyCheckFrom(address(5));
    }

    function testRootLeave() public {
        address root = anthill.readRoot();
        assertEq(root, address(2));

        address rootV2 = anthill.readRecTreeVote(address(1), 0);
        assertEq(rootV2, address(2));
        
        anthill.leaveTree(address(2));

        root = anthill.readRoot();
        assertEq(root, address(4));

        rootV2 = anthill.readRecTreeVote(address(1), 0);
        assertEq(rootV2, address(4));

        assert(anthill.readSentTreeVote(address(4))==address(1));
        assert(anthill.readSentTreeVote(address(5))==address(4));

        dagConsistencyCheckFrom(address(4));
        treeConsistencyCheckFrom(address(4));
    }

    //////////////////////////////////////////
    ///////////// utils 

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
