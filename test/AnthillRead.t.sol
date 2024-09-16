// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AnthillDev.sol";
import {TreeVoteExtended, DagVoteExtended} from "../src/AnthillDev.sol";
import {Utils} from "./Utils.t.sol";

contract ReadFromFileAndDeployTest is Test, Utils {
    function setUp() public {}

    function testReadFromFileAndDeploy() public {
        TreeVoteExtended[] memory treeVotes;
        DagVoteExtended[] memory dagVotes;

        string memory json = vm.readFile("./script-out/example.json");
        bytes memory treeVotesB = vm.parseJsonBytes(json, "$.tree_votes");
        bytes memory dagVotesB = vm.parseJsonBytes(json, "$.dag_votes");

        treeVotes = abi.decode(treeVotesB, (TreeVoteExtended[]));
        dagVotes = abi.decode(dagVotesB, (DagVoteExtended[]));

        AnthillDev anthill = new AnthillDev();
    
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
}