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

        // we don't want votes between 4, 5 and 2. 
        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2)); // todo line this might have to be deleted. 

        
        for (uint256 depth=1 ; depth<=3; depth++){
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

        vm.stopBroadcast();

    }
}

contract SmallScript is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);


        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2"));

        // adding tree votes. For the numbering we are adding children for i, j voter. 
        for (uint256 depth=1 ; depth<3; depth++){
            for (uint256 verticalNum=0; verticalNum<2**(depth-1); verticalNum++){
                anthill.joinTree(address(uint160(2*(2**depth+verticalNum))), string("Name"),address(uint160(2**depth+verticalNum)));
                anthill.joinTree(address(uint160(2*(2**depth+verticalNum)+1)), string("Name"),address(uint160(2**depth+verticalNum)));
            }
        }

        // we don't want votes between 4, 5 and 2. 
        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));

        
        for (uint256 depth=1 ; depth<=2; depth++){
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

        vm.stopBroadcast();

    }
}

contract TutorialScript is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(privateKey);


        anthill = new Anthill();

        // simple logic, 2 3 are roots, 
        //for x there are two childre with addresses 2x, and 2x+1 
        
        // height 0
        anthill.joinTreeAsRoot(address(2), string("Some other person"));
        anthill.joinTree(address(4), string("Dhruv"), address(2));
        
     
            
        vm.stopBroadcast();

    }
}


contract JustDeploy is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey =  0x01 ;
        vm.startBroadcast(privateKey);


        anthill = new Anthill();
                
        anthill.joinTreeAsRoot(address(0xcD3aC7F2C0bB8cF66EBDdf54e1E73C29b4EEda41), "MMarton");

            anthill.joinTree(address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8), "TrueBence", address(0xcD3aC7F2C0bB8cF66EBDdf54e1E73C29b4EEda41));
                anthill.removeDagVote(address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8), address(0xcD3aC7F2C0bB8cF66EBDdf54e1E73C29b4EEda41));

                anthill.joinTree(address(0x16E203ea994D5cf97c7Ee1b50C812d0C2b1733AE) ,"Anon999", address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8));
                    anthill.removeDagVote(address(0x16E203ea994D5cf97c7Ee1b50C812d0C2b1733AE), address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8));

                    anthill.joinTree(address(0x70584a3387e038cCaCb8E64Beb8FAf90118B09d8) ,"Rob", address(0x16E203ea994D5cf97c7Ee1b50C812d0C2b1733AE));
                        anthill.removeDagVote(address(0x70584a3387e038cCaCb8E64Beb8FAf90118B09d8), address(0x16E203ea994D5cf97c7Ee1b50C812d0C2b1733AE));


                anthill.joinTree(address(0x12D53b387E8D3e171c891Cf1B15FC61EB881a5FA),  "Ago", address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8));
                    anthill.removeDagVote(address(0x12D53b387E8D3e171c891Cf1B15FC61EB881a5FA), address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8));
                
            anthill.joinTree(address(0x063089B0F679C5189F539140a4Ed076De368a528),  "Bence", address(0xcD3aC7F2C0bB8cF66EBDdf54e1E73C29b4EEda41) );
                anthill.removeDagVote(address(0x063089B0F679C5189F539140a4Ed076De368a528), address(0xcD3aC7F2C0bB8cF66EBDdf54e1E73C29b4EEda41));
                
                anthill.joinTree(address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1), "Aron", address(0x063089B0F679C5189F539140a4Ed076De368a528));
                    anthill.removeDagVote(address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1), address(0x063089B0F679C5189F539140a4Ed076De368a528));
                    anthill.addDagVote(address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1), address(0x575DF80B3D6911968160a2469a71FDE0003F7dC8), 1);

                    anthill.joinTree(address(0x17DB4852aa8dE2a2dF50Ee4cBE41f529458957B4), "Enlli", address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1));
                        anthill.removeDagVote(address(0x17DB4852aa8dE2a2dF50Ee4cBE41f529458957B4), address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1));
                        anthill.addDagVote(address(0x17DB4852aa8dE2a2dF50Ee4cBE41f529458957B4), address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1), 1);


                anthill.joinTree(address(0xE2fC7b6b27800D60b8037C59B8a4c5c034dc5419), "Kalman", address(0xeacD44e3E83a51De384e0eb25556f754219A7bF1));
                

        
        // dagVotes:
            // Aron -> TrueBence
            // Enlli -> Marton

        anthill.lockTree();
            
        vm.stopBroadcast();

    }
}

contract Redeploy is Script {
    Anthill public anthillNew;
    address oldAddress = 0xb2218969ECF92a3085B8345665d65FCdFED9F981;
    Anthill public anthillOld = Anthill(oldAddress);


     function run() public {
        uint256 privateKey =  0x01 ;

        vm.startBroadcast(privateKey);


        anthillNew = new Anthill();
        
        address root = anthillOld.readRoot();
        string memory rootName = anthillOld.readName(root);

        anthillNew.joinTreeAsRoot(root, rootName);

        readAndAddChildrenRec(root, anthillOld, anthillNew);
                           
        uint32 maxRelRootDepth = anthillOld.readMaxRelRootDepth();
        readAndAddDagVotesRec(maxRelRootDepth, root, anthillOld, anthillNew);

        anthillNew.lockTree();
            
        vm.stopBroadcast();

    }


    function readAndAddChildrenRec(address parent, Anthill anthillOld, Anthill anthillNew ) internal {
        uint32 childCount = anthillOld.readRecTreeVoteCount(parent);
        for (uint32 i=0; i<childCount; i++){
            address child = anthillOld.readRecTreeVote(parent, i);
            string memory childName = anthillOld.readName(child);
            anthillNew.joinTree(child, childName, parent);
            anthillNew.removeDagVote(child, parent);

            readAndAddChildrenRec(child, anthillOld, anthillNew);
        }
    }

    function readAndAddDagVotesRec(uint32 maxRelRootDepth, address voter, Anthill anthillOld, Anthill anthillNew) internal {

        for (uint32 dist=1; dist<=maxRelRootDepth; dist++){
           for (uint32 height = 0; height <= dist; height++){

                uint32 dagVoteCount = anthillOld.readSentDagVoteCount(voter, dist, height);
                for (uint32 i=0; i<dagVoteCount; i++){
                    DagVote memory dagVote = anthillOld.readSentDagVote(voter, dist, height, i);
                    anthillNew.addDagVote(voter, dagVote.id, dagVote.weight);
                }
            }
        }

        uint32 childCount = anthillOld.readRecTreeVoteCount(voter);
        for (uint32 i=0; i<childCount; i++){
            address child = anthillOld.readRecTreeVote(voter, i);
            readAndAddDagVotesRec(maxRelRootDepth, child, anthillOld, anthillNew);
        }
        
    }
}

contract AnthillScript1 is Script {
    Anthill public anthill;

    function run() public {
        uint256 privateKey = 0x01;
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
