// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {

    uint256 public REL_ROOT_DEPTH;

    mapping(address => address) public treeVote;

    mapping(address => uint256) public recTreeVoteCount;
    mapping(address => mapping(uint256 => address)) public recTreeVote;

    mapping(address => uint256) public sentDagVoteDiff;
    mapping(address => mapping(uint256 => uint256)) public sentDagVoteCount;
    mapping(address => mapping(uint256 => mapping(uint256 => address))) public sentDagVote;

    mapping(address => uint256) public recDagVoteDiff;
    mapping(address => mapping(uint256 => uint256)) public recDagVoteCount;
    mapping(address => mapping(uint256 => mapping(uint256 => address))) public recDagVote;

    // when we first join the tree
    function joinTree(address recipient) public {
        assert (treeVote[msg.sender] == address(0));
        treeVote[msg.sender] = recipient;
    }

    // when we first join the tree without a parent
    function joinTreeAsRoot() public {
        assert (treeVote[msg.sender] == address(0));
        treeVote[msg.sender] = address(1);
    }

    // to find our relative root, our ancestor at depth REL_ROOT_DEPTH
    function findRelRoot(address voter) public view returns (address relRoot){
        assert (treeVote[voter] != address(0));

        relRoot = voter;
        address parent = address(0);

        for (uint256 i = 0; i < REL_ROOT_DEPTH; i++) {
            parent = treeVote[relRoot];
            if (parent == address(1)) {
                break;
            }
            relRoot = parent;
        }
        return relRoot;
    }

    // to find the depth difference between two locally close voters. Locally close means the recipient is a descendant of the voter's relative root
    function findDepthDiff(address voter, address recipient) public view returns (bool isLocal, uint256 depthDiff){
        
        if ((treeVote[voter] != address(0)) || (treeVote[recipient] != address(0))) {
            return (false, 0);
        }

        address relRoot = findRelRoot(voter);
        address recipientAncestor = recipient;

        for (uint256 i = 0; i < REL_ROOT_DEPTH-1; i++) {
            if (recipientAncestor == relRoot) {
                return (true, REL_ROOT_DEPTH-i);
            }
            
            recipientAncestor = treeVote[relRoot];

            if (recipientAncestor == address(1)) {
                return (false, 0);
            }
        }
        return (false, 0);
    }

    // to find the distance between two voters at the same depth if that distance in under maxdistance
    function findDistance(address add1, address add2, uint256 maxDistance) public view returns (bool isLocal, uint256 distance) {
        if ( treeVote[add1] == address(0) || treeVote[add2] == address(0)) {
            return (false, 0);
        }

        if (treeVote[add1] == address(1) || treeVote[add2] == address(1)) {
            return (false, 0);
        }
        
        if (add1 == add2){
            return (true, 0);
        }

        if (maxDistance == 0) {
            return (false, 0);
        }

        (isLocal, distance) = findDistance(treeVote[add1], treeVote[add2], maxDistance -1);

        if (isLocal == true) {
            return (true, distance + 1);
        }

        return (false, 0);
    }

    // to check the existence and to find the position of a vote in a given row of the sentDagVote array
    function findDagVotePosAtDepth(address voter, address recipient, uint256 depth) public view returns (bool voted, uint256 votePos){
        
        uint256  diff = sentDagVoteDiff[voter];

        for (uint256 i = 0; i < sentDagVoteCount[voter][diff+depth] ; i++) {

            if (sentDagVote[voter][diff+depth][i] == recipient) {
                return (true, i);
            }
        }

        return (false, 0);

    }

    // to check the existence and to find the position of a vote in a given row of the recDagVote array
    function findRecDagVotePosAtDepth(address voter, address recipient, uint256 depth) public view returns (bool voted, uint256 votePos){
        
        uint256  diff = recDagVoteDiff[recipient];

        for (uint256 i = 0; i < recDagVoteCount[recipient][diff+depth] ; i++) {
            if (sentDagVote[recipient][diff+depth][i] == voter) {
                return (true, i);
            }
        }
        
        return (false, 0);
    }

    // to check the existence and to find the position of a vote in the sentDagVote array (depth diff is the row position, votePos is column pos) 
    function findDagVote(address voter, address recipient) public view returns (bool voted, uint256 depthDiff, uint256 votePos){
        bool votable; 
        (votable, depthDiff) = findDepthDiff(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0);
        }

        (voted,  votePos) = findDagVotePosAtDepth(voter, recipient, depthDiff);

        return (voted, depthDiff, votePos);
    }

    // to check the existence and to find the position of a vote in the recDagVote array (depth diff is the row position, votePos is column pos)
    function findRecDagVote(address voter, address recipient) public view returns (bool voted, uint256 depthDiff, uint256 votePos){
        (bool votable, uint256 depthDiff) = findDepthDiff(voter, recipient);
        
        if (votable == false) {
            return (false, 0, 0);
        }

        (voted, votePos) = findRecDagVotePosAtDepth(voter, recipient, depthDiff);

        return (voted, depthDiff, votePos);
    }

    // to add a vote to the sentDagVote array, and also to the corresponding recDagVote array
    function addSentDagVote(address voter, address recipient) public {
        (bool voted, uint256 depthDiff, uint256 votePos) = findDagVote(voter, recipient);
        assert (voted == false);

        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]] = recipient;
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] += 1;

        (bool recVoted, uint256 recDepthDiff, uint256 recVotePos) = findRecDagVote(voter, recipient);
        assert (recVoted == false);

        recDagVote[recipient][recDagVoteDiff[recipient]+recDepthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff]] = voter;
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff] += 1;        
    }

    // to remove a vote from the sentDagVote array, and also from the  corresponding recDagVote arrays
    function removeDagVote(address voter, address recipient) public {
        (bool voted, uint256 depthDiff, uint256 votePos) = findDagVote(voter, recipient);
        assert (voted == true);

        sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][votePos] = sentDagVote[voter][sentDagVoteDiff[voter]+depthDiff][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff]-1];
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depthDiff] -= 1;

        (bool recVoted, uint256 recDepthDiff, uint256 recVotePos) = findRecDagVote(voter, recipient);
        assert (recVoted == true);

        recDagVote[recipient][recDagVoteDiff[recipient]+recDepthDiff][recVotePos] = recDagVote[recipient][recDagVoteDiff[recipient]+recDepthDiff][recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff]-1];
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+recDepthDiff] -= 1;
    }

    // to remove a row of votes from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteRow(address voter, uint256 depth) public {
        for (uint256 i = 0; i < sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth]; i++) {
            address recipient = sentDagVote[voter][sentDagVoteDiff[voter]+depth][i];
            sentDagVote[voter][sentDagVoteDiff[voter]+depth][i] = address(0); 
            (bool recVoted, uint256 recVotePos) = findRecDagVotePosAtDepth(voter, recipient, depth);
            assert (recVoted == true);

            recDagVote[recipient][recDagVoteDiff[recipient]+depth][recVotePos] = recDagVote[recipient][recDagVoteDiff[recipient]+depth][recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth]-1];
            recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth] -= 1;
        }
        sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth] = 0;
    }

    // to remove a row of votes from the recDagVote array, and the corresponding votes from the sentDagVote arrays
    function removeRecDagVoteRow(address recipient, uint256 depth) public {
        for (uint256 i = 0; i < recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth]; i++) {
            address voter = recDagVote[recipient][recDagVoteDiff[recipient]+depth][i];
            recDagVote[recipient][recDagVoteDiff[recipient]+depth][i] = address(0); 
            (bool voted, uint256 votePos) = findDagVotePosAtDepth(voter, recipient, depth);
            assert (voted == true);

            sentDagVote[voter][sentDagVoteDiff[voter]+depth][votePos] = sentDagVote[voter][sentDagVoteDiff[voter]+depth][sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth]-1];
            sentDagVoteCount[voter][sentDagVoteDiff[voter]+depth] -= 1;
        }
        recDagVoteCount[recipient][recDagVoteDiff[recipient]+depth] = 0;
    }

    // to remove all rows over a certain depth from the sentDagVote array, and the corresponding votes from the recDagVote arrays
    function removeSentDagVoteOverDepthInclusive(address voter, uint256 depth) public {
        for (uint256 i = sentDagVoteDiff[voter] + depth; i < sentDagVoteDiff[voter] + REL_ROOT_DEPTH; i++) {
            removeSentDagVoteRow(voter, i);
        }
    }

    // to remove non-local votes when jumping distance and depth under the jumper.  
    function removeSentDagVoteDescendants(address voter, uint256 distance, uint256 depth) public {
        

        // we only need to remove votes if we jumped out of voter's local subtree.
        // Our local subtree is at depth REL_ROOT_DEPTH - depth above the jumper. 
        // We jump out of this if the distance is larger.
        if (REL_ROOT_DEPTH - depth < distance){
            // We jumped out of our local subtree.
            // We have to remove all votes not in subtree where the jumper is the root.
            // This means votes at the jumpers depth have to be removed (so also the jumper)
            removeSentDagVoteOverDepthInclusive(voter, depth);
        }
        
        // there are DAG vote only under REL_ROOT_DEPTH. If we are there we can stop.
        if (depth == REL_ROOT_DEPTH ) {
            return;
        }

        // we repeat the procedure for our decendants
        for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
            address recipient = recTreeVote[voter][i];
            removeSentDagVoteDescendants(recipient, distance, depth+1);
        }
    }




    function changeTreeVoteSameHeight(address voter, address recipient, uint256 maxDistance) public {
        (bool votable, uint256 diff) = findDepthDiff(voter, recipient);
        assert (diff == 1);

        (bool isLocal, uint256 distance) = findDistance(treeVote[voter], recipient, maxDistance);

        assert (isLocal == true);






    }

}
