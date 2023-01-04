// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Anthill.sol";

contract AnthillTest is Test {
    Anthill public anthill;

    function setUp() public {
        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2));
        //anthill.joinTreeAsRoot(address(3));

        // adding tree votes
        for (uint256 i=1 ; i<8; i++){
            for (uint256 j=0; j<2**i; j++){
                anthill.joinTree(address(uint160(2*2**i+2*j)), address(uint160(2**i+j)));
                anthill.joinTree(address(uint160(2*2**i+2*j+1)), address(uint160(2**i+j)));
            }
        }


        for (uint256 i=3 ; i<8; i++){
            for (uint256 j=0; j<2**i; j++){

                // e.g. 2*2**i+2*j = 2*2**3+2*0 = 2*8+0 = 16, this has relRoot 2. We give dag votes to 4, 5, 8, 9 10 11
                (address voter, ) = anthill.findRelRoot(address(uint160(2*2**i+2*j)));

                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2*uint160(voter)));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+2*uint160(voter)));
                
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(voter)));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(voter)));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(voter)));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(voter)));
                
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

    function testParents() public {
        address a = anthill.readTreeVote( anthill.readTreeVote( anthill.readTreeVote(address(23))));
        assertEq(a, address(2));
    }

    function testAddAndRemoveDagVote(uint256 x) public {
        anthill.addDagVote(   address(8),address(5));
        // anthill.removeDagVote(address(8),address(5));

        
    }

    function testJump(uint256 x) public {
        
    }
}
