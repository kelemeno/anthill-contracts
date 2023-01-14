// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Anthill.sol";
import {Dag, DagVote} from "../src/Anthill.sol";

contract AnthillScript3 is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);


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
                        
                        // we don't want votes between 4, 5 and 2. 
                        if ((depth==2) && (recDepth ==1)) continue;
                        anthill.addDagVote(address(uint160(2**depth+verticalNum)), address(uint160(2**recDepth+recVerticalNum)), weight);
                    }
                }                
            }
        }    

        vm.stopBroadcast();

    }
}

contract AnthillScript1 is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);


        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        //anthill.joinTreeAsRoot(address(3));

        // adding tree votes
        for (uint256 i=1 ; i<8; i++){
            for (uint256 j=0; j<2**(i-1); j++){
                anthill.joinTree(address(uint160(2*2**i+2*j)), string("Name"), address(uint160(2**i+j)) );
                anthill.joinTree(address(uint160(2*2**i+2*j+1)),string("Name"),  address(uint160(2**i+j)));
            }
        }

        // adding dag votes
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

        vm.stopBroadcast();

 }

    
}

contract AnthillScript2 is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);


        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));
        // anthill.joinTreeAsRoot(address(3), string("root 3, we will want to remove second roots "));

        // adding tree votes
        for (uint256 i=1 ; i<5; i++){
            for (uint256 j=0; j<2**(i-1); j++){
                anthill.joinTree(address(uint160(2*(2**i+j)  )), string("Name"), address(uint160(2**i+j)));
                anthill.joinTree(address(uint160(2*(2**i+j)+1)), string("Name"),address(uint160(2**i+j)));
            }
        }

        

        // adding dag votes
        // we add layers 3, 4
        // then we add 
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

        vm.stopBroadcast();

 }

    
}
