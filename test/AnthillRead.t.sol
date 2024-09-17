// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol"; // OpenZeppelin provides this library

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AnthillDev.sol";
import {TreeVoteExtended, DagVoteExtended} from "../src/AnthillDev.sol";
import {Utils} from "./Utils.t.sol";

struct Logs {
    address address2;
    bytes32[] topics;
    bytes data;
    bytes32 blockHash;
    uint256 blockNumber;
    uint256 blockTimestamp;
    bytes32 transactionHash;
    uint256 transactionIndex;
    uint256 logIndex;
    bool removed;
}

contract ReadFromFileAndDeployTest is Test, Utils {
    using Strings for uint256; // Attach the Strings library to uint256

    AnthillDev anthill;

    function setUp() public {}

    function readFromFileAndDeploy() public {
        TreeVoteExtended[] memory treeVotes;
        DagVoteExtended[] memory dagVotes;

        string memory json = vm.readFile("./script-out/example.json");
        bytes memory treeVotesB = vm.parseJsonBytes(json, "$.tree_votes");
        bytes memory dagVotesB = vm.parseJsonBytes(json, "$.dag_votes");

        treeVotes = abi.decode(treeVotesB, (TreeVoteExtended[]));
        dagVotes = abi.decode(dagVotesB, (DagVoteExtended[]));

        anthill = new AnthillDev();
    
        for (uint256 i = 0; i < treeVotes.length; i++) {
            TreeVoteExtended memory treeVote = treeVotes[i];
            anthill.setVoterData(treeVote);
        }
        for (uint256 i = 0; i < dagVotes.length; i++) {
            DagVoteExtended memory dagVote = dagVotes[i];
            anthill.setDagVote(dagVote);
        }        


        // Perform consistency check
        // treeConsistencyCheckFrom(anthill, anthill.root());
        // dagConsistencyCheckFrom(anthill, anthill.root());
    }
    struct Tet {
        uint256 a;
        uint256 b;
    }

    function reexecute() public {
        string memory json = vm.readFile("./script-out/encodedLogs.json");
        bytes memory logsB = vm.parseJson(json, "$.encodedLogs");
        uint256 len = vm.parseJsonUint(json, "$.encodedLogsLength");
        for (uint256 i = 0; i < len; i++) {
            string memory iterator = i.toString();
            string memory json = vm.readFile(string.concat("./script-out/encodedLogs/", iterator, ".json"));
            bytes memory logB = vm.parseJsonBytes(json, "$.encodedLog");
            // Tet memory log = abi.decode(logB, (Tet));
            // console.log(log.a, log.b);
        }
        // console.logBytes(logsB);
        // Tet[] memory array = getTet(); 
        // // array[0] = Tet(9, 9);
        // // array[1] = Tet(10, 10);
        // bytes memory testB = abi.encode(array);
        // console.logBytes(testB);
        // Tet[] memory test = abi.decode(logsB, (Tet[]));
        // Logs[len] memory logs = abi.decode(logsB, (Logs[len]));

        // for (uint256 i = 0; i < logs.length; i++) {
        //     Logs memory log = logs[i];
        //     console.log(log.address2);
        // }
    }


    function getTet() public returns (Tet[] memory array) {
        array[0] = Tet(9, 9);
        array[1] = Tet(10, 10);
    }

    function test_deployAndReexecute() public {
        // readFromFileAndDeploy();
        reexecute();
    }
}