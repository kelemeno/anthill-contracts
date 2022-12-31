// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Anthill.sol";

contract AnthillScript is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);


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
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+2*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                
                // // in this case we add dag votes to depth one above us
                // if (i>=4){
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(1+4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(2+4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                //     anthill.addDagVote(address(uint160(2*2**i+2*j)), address(3+4*uint160(anthill.findRelRoot(address(uint160(2*2**i+2*j))))));
                // }

                
            }
        }      

        vm.stopBroadcast();

 }

    
}
