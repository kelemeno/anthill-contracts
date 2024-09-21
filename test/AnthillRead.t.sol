// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol"; // OpenZeppelin provides this library

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {AnthillDev} from "../src/AnthillDev.sol";
import {Anthill2Dev} from "../src/Anthill2Dev.sol";
import {TreeVoteExtended, DagVoteExtended} from "../src/IAnthillDev.sol";
import {Utils} from "./Utils.t.sol";
import {IAnthill} from "../src/IAnthill.sol";
import {IAnthillDev} from "../src/IAnthillDev.sol";

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

    IAnthillDev anthill;

    function setUp() public {}

    function readFromFileAndDeploy() public {
        TreeVoteExtended[] memory treeVotes;
        DagVoteExtended[] memory dagVotes;

        string memory json = vm.readFile("./script-out/example.json");
        bytes memory treeVotesB = vm.parseJsonBytes(json, "$.tree_votes");
        bytes memory dagVotesB = vm.parseJsonBytes(json, "$.dag_votes");

        treeVotes = abi.decode(treeVotesB, (TreeVoteExtended[]));
        dagVotes = abi.decode(dagVotesB, (DagVoteExtended[]));

        Anthill2Dev anthillC = new Anthill2Dev();
        anthill = anthillC;
    
        for (uint256 i = 0; i < treeVotes.length; i++) {
            TreeVoteExtended memory treeVote = treeVotes[i];
            anthill.setVoterData(treeVote);
        }
        for (uint256 i = 0; i < dagVotes.length; i++) {
            DagVoteExtended memory dagVote = dagVotes[i];
            anthill.setDagVote(dagVote);
        }        
    }

    function reexecute() public {
        string memory json = vm.readFile("./script-out/encodedLogsLength.json");
        uint256 len = vm.parseJsonUint(json, "$.encodedLogsLength");
        Logs[] memory logs = new Logs[](len);
        for (uint256 i = 0; i < len; i++) {
            string memory iterator = i.toString();
            string memory json = vm.readFile(string.concat("./script-out/encodedLogs/", iterator, ".json"));
            bytes memory logB = vm.parseJsonBytes(json, "$.encodedLog");
            Logs memory log = abi.decode(logB, (Logs));
            logs[i] = log;
        }

        for (uint256 i = 0; i < logs.length; i++) {
            Logs memory log = logs[i];
            console.log("log", i);
            console.logBytes32(log.transactionHash);
            if (log.removed) {
                console.log("removed");
                continue;
            }
            if (i == 22) {
                printSentDagVotes(anthill, address(0xf51BdfC3fa38bcFDb83F20489d7c3A4415Da236e));
            }
            executeLog(anthill, log);
            console.log("running consistency check");
            address root = address(1);
            if (anthill.readRecTreeVoteCount(address(1)) == 0) {
                root = anthill.readRoot();
            }
            treeConsistencyCheckFrom(anthill, root);
            dagConsistencyCheckFrom(anthill, root);
        }
    }

    function executeLog(IAnthillDev anthill, Logs memory log) internal {
        if (log.topics[0] == IAnthill.JoinTreeEvent.selector) {
            console.log("JoinTreeEvent");
            (address voter, string memory name, address recipient) = abi.decode(log.data, (address, string, address));
            anthill.joinTree(voter, name, recipient);
        } else if (log.topics[0] == IAnthill.ChangeNameEvent.selector) {
            console.log("ChangeNameEvent");
            (address voter, string memory newName) = abi.decode(log.data, (address, string));
            anthill.changeName(voter, newName);
        } else if (log.topics[0] == IAnthill.AddDagVoteEvent.selector) {
            console.log("AddDagVoteEvent");
            (address voter, address recipient, uint256 weight) = abi.decode(log.data, (address, address, uint256));
            // we probaby do an additional 
            (address id) = anthill.treeVote(voter);
            if (id == address(0)) {
                console.log("wrong even order bug, skipping"); // when a person joins the tree, they send a dag vote to their parent, and after that emit a JoinTreeEvent
                return;
            }
            anthill.addDagVote(voter, recipient, weight);
        } else if (log.topics[0] == IAnthill.RemoveDagVoteEvent.selector) {
            console.log("RemoveDagVoteEvent");
            (address voter, address recipient) = abi.decode(log.data, (address, address));
            anthill.removeDagVote(voter, recipient);
        } else if (log.topics[0] == IAnthill.LeaveTreeEvent.selector) {
            console.log("LeaveTreeEvent");
            (address voter) = abi.decode(log.data, (address));
            anthill.leaveTree(voter);
        } else if (log.topics[0] == IAnthill.SwitchPositionWithParentEvent.selector) {
            console.log("SwitchPositionWithParentEvent");
            (address voter) = abi.decode(log.data, (address));
            anthill.switchPositionWithParent(voter);
        } else if (log.topics[0] == IAnthill.MoveTreeVoteEvent.selector) {
            console.log("MoveTreeVoteEvent");
            (address voter, address recipient) = abi.decode(log.data, (address, address));
            anthill.moveTreeVote(voter, recipient);
        }
    }

    function test_deployAndReexecute() public {
        readFromFileAndDeploy();
        reexecute();
        address root = address(1);
        if (anthill.readRecTreeVoteCount(address(1)) == 0) {
            root = anthill.readRoot();
        }
        treeConsistencyCheckFrom(anthill, root);
        dagConsistencyCheckFrom(anthill, root);
        address marcin = address(0xFb60921A1Dc09bFEDa73e26CB217B0fc76c41461);
        dagConsistencyCheckFrom(anthill, marcin);
        printSentDagVotes(anthill, marcin);

        (bool isLocal, uint256 recordedDist, uint256 recordedRDist) = anthill.findDistancesRecNotLower(marcin, address(0xD5A498Bbc6D21E4E1cdBB8fec58e3eCD7124FB43));
        console.log("isLocal", isLocal);
        console.log("recordedDist", recordedDist);
        console.log("recordedRDist", recordedRDist);
    }
}