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
        for (uint256 i=1 ; i<8; i++){
            for (uint256 j=0; j<2**(i-1); j++){
                console.log("i, j", i, j);
                anthill.joinTree(address(uint160(2*2**i+2*j)), string("Name"),address(uint160(2**i+j)));
                anthill.joinTree(address(uint160(2*2**i+2*j+1)), string("Name"),address(uint160(2**i+j)));
            }
        }

        // anthill.addDagVote(address(8), address(5), 1);

        for (uint256 i=3 ; i<8; i++){
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
        (bool isLocal, uint32 dist ) = anthill.findDistAtSameDepth(address(4),address(5), 10);
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
        assertEq(dist, 2);
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

    function testJump() public {
        
    }
}
