// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Anthill.sol";
import {console} from "forge-std/console.sol";


contract AnthillTest is Test {
    Anthill public anthill;

    function setUp() public {
        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));

        // adding tree votes 
        for (uint256 i=1 ; i<5; i++){
            for (uint256 j=0; j<2**(i-1); j++){
                // console.log("i, j", i, j);
                anthill.joinTree(address(uint160(2*2**i+2*j)), string("Name"),address(uint160(2**i+j)));
                anthill.joinTree(address(uint160(2*2**i+2*j+1)), string("Name"),address(uint160(2**i+j)));
            }
        }

        // anthill.addDagVote(address(8), address(5), 1);
        
        // we do this for heights 3, 4, 5, 6, 7
        // we add 2**(i-1) so 2, 4, 8, 16, 32 votes. that is 62 dag voters. Each splits their votes into 5. That should be around 12 rep.  
        for (uint256 i=3 ; i<5; i++){
            for (uint256 j=0; j<2**(i-1); j++){

                // e.g. 2*2**i+2*j = 2*2**3+2*0 = 2*8+0 = 16, this has relRoot 2. We give dag votes to 4, 5, 8, 9 10 11
                (address voter, ) = anthill.findRelRoot(address(uint160(2*2**i+2*j)));

                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2*uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+2*uint160(voter)), 1);
                
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(voter)), 1);
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(voter)), 1);
                
                // // in this case we add dag votes to depth one above us
                // if (i>=4){
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(voter)));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(voter)));
                // }

                
            }
        }      
    }

    // function testParents() public {
    //     address a = anthill.readSentTreeVote( anthill.readSentTreeVote( anthill.readSentTreeVote(address(23))));
    //     assertEq(a, address(2));
    // }

    function testFindRelDepth() public {
        (, uint32 depth ) = anthill.findRelDepth(address(8), address(5));
        assertEq(depth, 1);
    }

    function testFindNthParent() public {
        (address voteA ) = anthill.findNthParent(address(8),1);
        assertEq(voteA, address(4));
    }

    function testFindDistAtSameDepth() public {
        (bool isLocal, uint32 dist ) = anthill.findDistAtSameDepth(address(4),address(5));
        assertEq(1, dist);
    }

    function testFindSentDagVote() public {
        (bool voted, uint32 dist, uint32 depth, uint32 votePos, ) = anthill.findSentDagVote(address(8),address(5));
        assertEq(2, dist);
        assertEq(1, depth);
        assertEq(voted, false);
    }

    function testAddAndRemoveDagVote() public {
        anthill.addDagVote(address(8),address(5), 1);
        (bool voted, uint32 dist, uint32 depth, , ) = anthill.findSentDagVote(address(8), address(5));
        assertEq(voted, true);
        assertEq(dist, 2);
        assertEq(depth, 1);

        (voted,  dist,  depth, , ) = anthill.findRecDagVote(address(8), address(5));
        assertEq(voted, true);
        assertEq(dist, 2);
        assertEq(depth, 1);

        anthill.removeDagVote(address(8),address(5));
        ( voted,  dist,  depth, , ) = anthill.findSentDagVote(address(8), address(5));
        assertEq(voted, false);

        ( voted,  dist,  depth, , ) = anthill.findRecDagVote(address(8), address(5));
        assertEq(voted, false);

    }

    function testAddAndRemoveDagVote2() public {
        // anthill.addDagVote(address(34),address(9), 1);
        (bool voted, uint32 dist, uint32 depth, , ) = anthill.findSentDagVote(address(34), address(9));
        assertEq(voted, true);
        assertEq(dist, 3);
        assertEq(depth, 2);

        (voted,  dist,  depth, , ) = anthill.findRecDagVote(address(34), address(9));
        assertEq(voted, true);
        assertEq(dist, 3);
        assertEq(depth, 2);

        anthill.removeDagVote(address(34),address(9));
        ( voted,  dist,  depth, , ) = anthill.findSentDagVote(address(34), address(9));
        assertEq(voted, false);

        ( voted,  dist,  depth, , ) = anthill.findRecDagVote(address(34), address(9));
        assertEq(voted, false);

    }

    function testCalculateRep() public {
        uint256 rep = anthill.calculateReputation(address(4));
        uint256 rep2 = anthill.calculateReputation(address(2));
        console.log(rep);
        console.log(rep2);

        // assert(rep  +100- 3000000000000000000< 1000);
        // assert(rep2 +100- 1000000000000000000< 1000);

    }

    function testChangeDistDepthRec() public {
        (bool voted, uint32 dist, uint32 depth, uint32 votePos, Anthill.DagVote memory rDagVote) = anthill.findRecDagVote(address(16), address(4));
        assertEq(voted, true);
        assertEq(dist, 2);
        assertEq(depth, 2);
        assertEq(votePos, 0);

        anthill.unsafeReplaceRecDagVoteAtDistDepthPosWithLast(address(4), 2, 2, 0);

        uint32 count = anthill.readRecDagVoteCount(address(4), 2, 2);
        assertEq(count, 1); 
        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 2);

        anthill.recDagAppend(address(4), 3, 2, address(16), rDagVote.weight, anthill.readSentDagVoteCount(address(16), 3, 2));
        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 3);

        anthill.changeDistDepthSent(address(16), 2, 2, rDagVote.posInOther, address(4), anthill.readRecDagVoteCount(address(4), 3, 2)-1, rDagVote.weight, 3, 2);
        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 3);
        intermediateConsistencyCheckFrom(address(2));
    }

    function testMerge() public{
       
        uint32 count = anthill.readRecDagVoteCount(address(4), 2, 2);
        assertEq(count, 2); 
        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 2); 
       
        anthill.mergeRecDagVoteDiagonalCell(address(4), 2);
       
        count = anthill.readRecDagVoteCount(address(4), 2, 2);
        assertEq(count, 0); 

        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 4); 

        // anthill.changeDistDepthFromRecCellOnOp(address(4), 3, depth, oldDist, oldDepth);
        intermediateConsistencyCheckFrom(address(2));
    }

    function testChangeDistDepthFromRecCellOnOp() public {
        // first we clear a cell
        uint32 count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 2);
        anthill.removeRecDagVoteCell(address(4), 3, 2);
        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 0);

        // then we move a cell to it
        count = anthill.readRecDagVoteCount(address(4), 2, 2);
        assertEq(count, 2);

        for (uint32 i = 0; i < anthill.readRecDagVoteCount(address(4), 2, 2); i++){
            Anthill.DagVote memory rDagVote = anthill.readRecDagVote(address(4), 2, 2, i);
            anthill.recDagAppend(address(4), 3, 2, rDagVote.id, rDagVote.weight, rDagVote.posInOther);
        }

        count = anthill.readRecDagVoteCount(address(4), 3, 2);
        assertEq(count, 2);

        // remove the moved cell
        for (uint32 i = anthill.readRecDagVoteCount(address(4), 2, 2)  ; i >= 1; i--){
            anthill.unsafeReplaceRecDagVoteAtDistDepthPosWithLast(address(4), 2, 2, i-1);
            
        }

        count = anthill.readRecDagVoteCount(address(4), 2, 2);
        assertEq(count, 0);
        anthill.changeDistDepthFromRecCellOnOp(address(4), 3, 2, 2, 2);
        intermediateConsistencyCheckFrom(address(2));
    }

    function testSwitchPositionWithParent() public {
        address root = anthill.readRoot();
        assertEq(root, address(2));
        
        anthill.switchPositionWithParent(address(4));
        root = anthill.readRoot();
        assertEq(root, address(4));



        // for (uint32 i = 0; i < 7; i++){
        //     for (uint32 j = 0; j < 7; j++){
        //         uint32 sentCount = anthill.readRecDagVoteCount(address(4), i,j);
        //         console.log(i, j, sentCount);
        //     }
        // }

        uint256 rep = anthill.calculateReputation(address(4));

        // for (uint32 i = 16; i < 23; i=i+2){
        //         uint32 sentWeight = anthill.readSentDagVoteTotalWeight(address(uint160(i)));
        //         console.log(i, sentWeight);
        // }
        //  for (uint32 i = 32; i < 47; i=i+2){
        //         uint32 sentWeight = anthill.readSentDagVoteTotalWeight(address(uint160(i)));
        //         console.log(i, sentWeight);
        // }

        uint256 rep2 = anthill.calculateReputation(address(2));

        assert(rep +100- 3000000000000000000< 200);
        assert(rep2 +100- 1000000000000000000< 200);

        assert(anthill.readSentTreeVote(address(16))==address(8));
        assert(anthill.readSentTreeVote(address(8))==address(2));
        assert(anthill.readSentTreeVote(address(2))==address(4));
        assert(anthill.readSentTreeVote(address(10))==address(5));
        assert(anthill.readSentTreeVote(address(5))==address(4));

        consistencyCheckFrom(address(4));
    }


    function intermediateConsistencyCheckFrom(address voter) public {

        for (uint32 dist = 0; dist < 7; dist++){
            for (uint32 depth = 0; depth < 7; depth++){
                for (uint32 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++){
                    Anthill.DagVote memory sDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                    Anthill.DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, dist, depth, sDagVote.posInOther);
                    (bool isLocal, ,) = anthill.findDistDepth(voter, sDagVote.id);
                    assert( isLocal);
                    // console.log("id", voter, rDagVote.id, sDagVote.id);
                    assertEq(rDagVote.id, voter);
                    assertEq(rDagVote.weight, sDagVote.weight);
                    assertEq(rDagVote.posInOther, i);

                    
                }

                for (uint32 i = 0; i < anthill.readRecDagVoteCount(voter, dist, depth); i++){
                    Anthill.DagVote memory rDagVote = anthill.readRecDagVote(voter, dist, depth, i);
                    Anthill.DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, dist, depth, rDagVote.posInOther);

                    (bool isLocal, ,) = anthill.findDistDepth(rDagVote.id, voter);
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
            intermediateConsistencyCheckFrom(anthill.readRecTreeVote(voter, i));
        } 
    }

    function consistencyCheckFrom(address voter) public {

        for (uint32 dist = 0; dist < 7; dist++){
            for (uint32 depth = 0; depth < 7; depth++){
                for (uint32 i = 0; i < anthill.readSentDagVoteCount(voter, dist, depth); i++){
                    Anthill.DagVote memory sDagVote = anthill.readSentDagVote(voter, dist, depth, i);
                    Anthill.DagVote memory rDagVote = anthill.readRecDagVote(sDagVote.id, dist, depth, sDagVote.posInOther);
                    (bool isLocal, uint32 recordedDist, uint32 recordedDepth) = anthill.findDistDepth(voter, sDagVote.id);
                    assert( isLocal);
                    // console.log("id", voter, rDagVote.id, sDagVote.id);
                    assertEq(rDagVote.id, voter);
                    assertEq(rDagVote.weight, sDagVote.weight);
                    assertEq(rDagVote.posInOther, i);

                    assertEq(recordedDist, dist);
                    assertEq(recordedDepth, depth);
                }

                for (uint32 i = 0; i < anthill.readRecDagVoteCount(voter, dist, depth); i++){
                    Anthill.DagVote memory rDagVote = anthill.readRecDagVote(voter, dist, depth, i);
                    Anthill.DagVote memory sDagVote = anthill.readSentDagVote(rDagVote.id, dist, depth, rDagVote.posInOther);

                    (bool isLocal, uint32 recordedDist, uint32 recordedDepth) = anthill.findDistDepth(rDagVote.id, voter);
                    assert( isLocal);
                    
                    // console.log("voter: ", voter);
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
            consistencyCheckFrom(anthill.readRecTreeVote(voter, i));
        } 
    }

    
}
