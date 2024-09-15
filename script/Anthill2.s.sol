// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {stdToml} from "forge-std/StdToml.sol";

import {Anthill, IAnthill} from "../src/Anthill.sol";
import {DagVote} from "../src/Anthill.sol";
import {TreeVoteExtended, DagVoteExtended, AnthillDev} from "../src/AnthillDev.sol";

contract AnthillScript3 is Script {
    Anthill public anthill;

    function run() public {
        // hardhat rich private key
        // uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        // era-test node rich private key
        uint256 eraTestNodePrivateKey = 0x3d3cbc973389cb26f657686445bcc75662b415b656078503592ac8c1abb8810e;
        vm.startBroadcast(eraTestNodePrivateKey);

        anthill = new Anthill();

        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2 "));

        // adding tree votes. For the numbering we are adding children for i, j voter.
        for (uint256 depth = 1; depth < 5; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum))),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum) + 1)),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
            }
        }

        // we don't want votes between 4, 5 and 2.
        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2)); // todo line this might have to be deleted.

        for (uint256 depth = 1; depth <= 3; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                for (uint256 recDepth = 1; recDepth < depth; recDepth++) {
                    // we want 2 to receive less, and the second lowest layer to receive more votes.
                    uint256 weight = 1000;
                    if (recDepth == 1) {
                        weight = 1;
                    } else if (recDepth == 4) {
                        weight = 100000;
                    }

                    for (uint256 recVerticalNum = 0; recVerticalNum < 2 ** (recDepth - 1); recVerticalNum++) {
                        // we cannot add votes between parents and children, as we already added those votes in joinTree
                        if (2 ** depth + verticalNum >= 2 * (2 ** recDepth + recVerticalNum)) {
                            if (2 ** depth + verticalNum - 2 * (2 ** recDepth + recVerticalNum) == 0) continue;
                            if (2 ** depth + verticalNum - 2 * (2 ** recDepth + recVerticalNum) == 1) continue;
                        }

                        anthill.addDagVote(
                            address(uint160(2 ** depth + verticalNum)),
                            address(uint160(2 ** recDepth + recVerticalNum)),
                            weight
                        );
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
        // hardhat rich private key
        // uint256 anvilPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        // vm.startBroadcast(anvilPrivateKey);

        // era-test node rich private key
        uint256 eraTestNodePrivateKey = 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110;
        vm.startBroadcast(eraTestNodePrivateKey);

        anthill = new Anthill();

        // simple logic, 2 3 are roots,
        //for x there are two childre with addresses 2x, and 2x+1

        // height 0
        anthill.joinTreeAsRoot(address(2), string("Root2"));

        // adding tree votes. For the numbering we are adding children for i, j voter.
        for (uint256 depth = 1; depth < 3; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum))),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
                anthill.joinTree(
                    address(uint160(2 * (2 ** depth + verticalNum) + 1)),
                    string("Name"),
                    address(uint160(2 ** depth + verticalNum))
                );
            }
        }

        // we don't want votes between 4, 5 and 2.
        anthill.removeDagVote(address(4), address(2));
        anthill.removeDagVote(address(5), address(2));

        for (uint256 depth = 1; depth <= 2; depth++) {
            for (uint256 verticalNum = 0; verticalNum < 2 ** (depth - 1); verticalNum++) {
                for (uint256 recDepth = 1; recDepth < depth; recDepth++) {
                    // we want 2 to receive less, and the second lowest layer to receive more votes.
                    uint256 weight = 1000;
                    if (recDepth == 1) {
                        weight = 1;
                    } else if (recDepth == 4) {
                        weight = 100000;
                    }

                    for (uint256 recVerticalNum = 0; recVerticalNum < 2 ** (recDepth - 1); recVerticalNum++) {
                        // we cannot add votes between parents and children, as we already added those votes in joinTree
                        if (2 ** depth + verticalNum >= 2 * (2 ** recDepth + recVerticalNum)) {
                            if (2 ** depth + verticalNum - 2 * (2 ** recDepth + recVerticalNum) == 0) continue;
                            if (2 ** depth + verticalNum - 2 * (2 ** recDepth + recVerticalNum) == 1) continue;
                        }

                        anthill.addDagVote(
                            address(uint160(2 ** depth + verticalNum)),
                            address(uint160(2 ** recDepth + recVerticalNum)),
                            weight
                        );
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
        // hardhat rich private key
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
        // uint256 privateKey = 0x01;
        vm.startBroadcast();

        address zach = address(0xD5A498Bbc6D21E4E1cdBB8fec58e3eCD7124FB43);
        anthill = new Anthill();
        anthill.joinTreeAsRoot(zach, string("Zach"));
        anthill.joinTree(address(0x343Ee72DdD8CCD80cd43D6Adbc6c463a2DE433a7), string("Kalman"), zach);

        vm.stopBroadcast();
    }
}

contract Redeploy is Script {
    Anthill public anthillNew;
    address oldAddress = 0x69649a6E7E9c090a742f0671C64f4c7c31a1e4ce;
    Anthill public anthillOld = Anthill(oldAddress);

    function run() public {
        uint256 privateKey = 0x01;

        vm.startBroadcast(privateKey);

        anthillNew = new Anthill();

        address root = anthillOld.readRoot();
        string memory rootName = anthillOld.readName(root);

        anthillNew.joinTreeAsRoot(root, rootName);

        readAndAddChildrenRec(root, anthillOld, anthillNew);

        uint256 maxRelRootDepth = anthillOld.readMaxRelRootDepth();
        readAndAddDagVotesRec(maxRelRootDepth, root, anthillOld, anthillNew);

        anthillNew.lockTree();

        vm.stopBroadcast();
    }

    function readAndAddChildrenRec(address parent, Anthill anthillOldInput, Anthill anthillNewInput) internal {
        uint256 childCount = anthillOldInput.readRecTreeVoteCount(parent);
        for (uint256 i = 0; i < childCount; i++) {
            address child = anthillOldInput.readRecTreeVote(parent, i);
            string memory childName = anthillOldInput.readName(child);
            anthillNewInput.joinTree(child, childName, parent);
            anthillNewInput.removeDagVote(child, parent);

            readAndAddChildrenRec(child, anthillOldInput, anthillNewInput);
        }
    }

    function readAndAddDagVotesRec(
        uint256 maxRelRootDepth,
        address voter,
        Anthill anthillOldInput,
        Anthill anthillNewInput
    ) internal {
        for (uint256 dist = 1; dist <= maxRelRootDepth; dist++) {
            for (uint256 height = 0; height <= dist; height++) {
                uint256 dagVoteCount = anthillOldInput.readSentDagVoteCount(voter, dist, height);
                for (uint256 i = 0; i < dagVoteCount; i++) {
                    DagVote memory dagVote = anthillOldInput.readSentDagVote(voter, dist, height, i);
                    anthillNewInput.addDagVote(voter, dagVote.id, dagVote.weight);
                }
            }
        }

        uint256 childCount = anthillOldInput.readRecTreeVoteCount(voter);
        for (uint256 i = 0; i < childCount; i++) {
            address child = anthillOldInput.readRecTreeVote(voter, i);
            readAndAddDagVotesRec(maxRelRootDepth, child, anthillOldInput, anthillNewInput);
        }
    }
}

interface IRandom {
    function timestamp() external view returns (uint256);
}

contract JustRoot is Script {
    // address public oldAddress = 0xAe45cBE2d1E90358CbD216bC16f2C9267a4EA80a;
    address oldAddress = 0xe42923350EF3a534f84bb101453D9B442d42Bf0c;
    // address oldAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    IAnthill public anthillOld = IAnthill(oldAddress);
    // IRandom public random = IRandom(oldAddress);

    function run() public {
        // uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        // vm.createSelectFork(vm.rpcUrl("zksepolia"));
        // vm.startBroadcast();

        console.log(block.chainid);

        // console.log()
        // console.logBytes(oldAddress.code);
        address root = anthillOld.readRoot();
        // uint256 root = random.timestamp();
        console.log("root", root);
        // try anthillOld.readRoot() returns (address root) {
        //     console.log("root", root);
        // } catch (bytes memory reason) {
        //     console.logBytes(reason);
        // }
        // vm.stopBroadcast();
    }
}

contract ReadAndSave is Script {
    Anthill public anthillNew;
    address public oldAddress = 0xe42923350EF3a534f84bb101453D9B442d42Bf0c;
    Anthill public anthillOld = Anthill(oldAddress);
    TreeVoteExtended[] public treeVotes;
    DagVoteExtended[] public dagVotes;

    function run() public {
        address root = anthillOld.root();
        string memory rootName = anthillOld.readName(root);

        readChildrenRec(root, anthillOld, anthillNew);

        uint256 maxRelRootDepth = anthillOld.readMaxRelRootDepth();
        readDagVotesRec(maxRelRootDepth, root, anthillOld, anthillNew);

        string memory obj1 = "key";
        vm.serializeBytes(obj1, "tree_votes", abi.encode(treeVotes));
        string memory finalJson = vm.serializeBytes(obj1, "dag_votes", abi.encode(dagVotes));

        vm.writeJson(finalJson, "./script-out/example.json");

        vm.stopBroadcast();
    }

    function readChildrenRec(address parent, Anthill anthillOldInput, Anthill anthillNewInput) internal {
        uint256 childCount = anthillOldInput.readRecTreeVoteCount(parent);
        for (uint256 i = 0; i < childCount; i++) {
            address child = anthillOldInput.readRecTreeVote(parent, i);
            string memory childName = anthillOldInput.readName(child);
            uint256 childRecTreeVoteCount = anthillOldInput.readRecTreeVoteCount(child);
            uint256 sentDagVoteCount = anthillOldInput.readSentDagVoteCount(child, 0, 0);
            uint256 sentDagVoteTotalWeight = anthillOldInput.readSentDagVoteTotalWeight(child);
            uint256 recDagVoteCount = anthillOldInput.readRecDagVoteCount(child, 0, 0);
            treeVotes.push(
                TreeVoteExtended(
                    child,
                    childName,
                    parent,
                    childRecTreeVoteCount,
                    sentDagVoteCount,
                    sentDagVoteTotalWeight,
                    recDagVoteCount
                )
            );

            readChildrenRec(child, anthillOldInput, anthillNewInput);
        }
    }

    function readDagVotesRec(
        uint256 maxRelRootDepth,
        address voter,
        Anthill anthillOldInput,
        Anthill anthillNewInput
    ) internal {
        for (uint256 dist = 1; dist <= maxRelRootDepth; dist++) {
            for (uint256 height = 0; height <= dist; height++) {
                uint256 dagVoteCount = anthillOldInput.readSentDagVoteCount(voter, dist, height);
                for (uint256 i = 0; i < dagVoteCount; i++) {
                    DagVote memory sDagVote = anthillOldInput.readSentDagVote(voter, dist, height, i);
                    DagVote memory rDagVote = anthillOldInput.readRecDagVote(sDagVote.id, 0, 0, sDagVote.posInOther);
                    dagVotes.push(
                        DagVoteExtended(
                            voter,
                            sDagVote.id,
                            sDagVote.weight,
                            dist,
                            rDagVote.dist,
                            i,
                            sDagVote.posInOther
                        )
                    );
                }
            }
        }

        uint256 childCount = anthillOldInput.readRecTreeVoteCount(voter);
        for (uint256 i = 0; i < childCount; i++) {
            address child = anthillOldInput.readRecTreeVote(voter, i);
            readDagVotesRec(maxRelRootDepth, child, anthillOldInput, anthillNewInput);
        }
    }
}

contract ReadFromFileAndDeploy is Script {
    function run() public {
        TreeVoteExtended[] memory treeVotes;
        DagVoteExtended[] memory dagVotes;

        string memory json = vm.readFile("./script-out/example.json");
        bytes memory treeVotesB = vm.parseJsonBytes(json, "$.tree_votes");
        bytes memory dagVotesB = vm.parseJsonBytes(json, "$.dag_votes");

        treeVotes = abi.decode(treeVotesB, (TreeVoteExtended[]));
        dagVotes = abi.decode(dagVotesB, (DagVoteExtended[]));

        console.log("treeVotes", treeVotes.length);
        console.log("dagVotes", dagVotes.length);
    }
}
