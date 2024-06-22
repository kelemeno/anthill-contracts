// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract AnthillUnused {
    //     // to remove non-local votes when jumping distance and depth under the jumper.
    //     // currently not used, so internal
    //     function removeSentDagVoteJumpingTogether(address voter, uint256 jumpDistance, uint256 depth) internal {
    //         // voter is not the jumper but its descendant, distance is the dist of the jump, and depth is how deep we are in the recursion, going down the tree.

    //         // we only need to remove votes if we jumped out of voter's local subtree.
    //         // if we are the jumpers, and jump out of our local subtree, we have to remove all our sent votes.
    //         // this would apply for the voter as well, except they keep the votes that are descendants of the jumper.

    //         // The voters local subtree is at depth MAX_REL_ROOT_DEPTH - depth above the jumper.
    //         // We jump out of this if the distance is larger.
    //         if (MAX_REL_ROOT_DEPTH - depth < jumpDistance){
    //             // We jumped out of our local subtree.
    //             // We remove all votes not under the jumper.
    //             removeDagVoteForJumpingAlone(voter, depth);
    //         }

    //         // there are DAG vote only under MAX_REL_ROOT_DEPTH. If we are there we can stop.
    //         if (depth == MAX_REL_ROOT_DEPTH ) {
    //             return;
    //         }

    //         // we repeat the procedure for our decendants
    //         for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
    //             address recipient = recTreeVote[voter][i];
    //             removeSentDagVoteJumpingTogether(recipient, jumpDistance, depth+1);
    //         }
    //     }

    //     // when rising a single depth up the tree,
    //     function removeDagVoteRisingTogether(address voter, uint256 depth) internal {
    //         if (MAX_REL_ROOT_DEPTH<= depth){
    //             return;
    //         }
    //         //////////// Wrong!!!! the triangle's right half, i.e. voters over dist, move up or down.

    //         removeDagVoteForRisingAlone(voter, depth);

    //         for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
    //             address recipient = recTreeVote[voter][i];
    //             removeDagVoteRisingTogether(recipient, depth+1);
    //         }
    //     }

    //     // when falling a single depth to one of our brothers,
    //     function removeDagVoteFallingTogether(address voter, uint256 depth) internal {
    //         if (MAX_REL_ROOT_DEPTH<= depth){
    //             return;
    //         }

    //         removeDagVoteForFallingAlone(voter, depth);

    //         for (uint256 i =0; i< recTreeVoteCount[voter]; i++) {
    //             address recipient = recTreeVote[voter][i];
    //             removeDagVoteFallingTogether(recipient, depth+1);
    //         }
    //     }

    //   function removeSentDagVoteLineDistEqualsDepthPlusValue(address voter, uint256 value) internal {
    //             for (uint256 i = value+1; i <= MAX_REL_ROOT_DEPTH; i++) {
    //                 removeSentDagVoteCell(voter, i, i-value);
    //             }
    //         }

    //         function removeRecDagVoteLineDistEqualsDepthPlusValue(address voter, uint256 value) internal {
    //             for (uint256 i = value+1; i <= MAX_REL_ROOT_DEPTH; i++) {
    //                 removeRecDagVoteCell(voter, i, i-value);
    //             }
    //         }

    //  function removeRecDagVoteLineDistEqualsValue(address voter, uint256 value) internal {
    //             for (uint256 i = 1; i <= value; i++) {
    //                 removeSentDagVoteCell(voter, value, i);
    //             }
    //         }

    //  function changeDistDepthSent(address voter, uint256 dist, uint256 depth, uint256 sPos, address recipient, uint256 rPos, uint256 weight, uint256 newDist, uint256 newDepth) internal{
    //             // here it is ok to use unsafe, as the the vote is moved, not removed
    //             unsafeReplaceSentDagVoteAtDistDepthPosWithLast(voter, dist, depth, sPos);
    //             sentDagAppend(voter, newDist, newDepth, recipient, weight, rPos);
    //         }

    // ///////////// Area removals, for single voters, across both tables
    //     // to remove all votes over a given distance from the DagVote arrays, and the corresponding votes from the DagVote arrays
    //     function removeDagVoteForJumpingAlone(address voter, uint256 dist) internal {
    //         for (uint256 i = dist; i < MAX_REL_ROOT_DEPTH; i++) {
    //             removeSentDagVoteLineDistEqualsValue(voter, sentDagVoteDepthDiff[voter]+ i);
    //             removeRecDagVoteLineDistEqualsValue(voter, recDagVoteDepthDiff[voter]+ i);
    //         }
    //     }

    //     // we remove the rows on the edges and change the frame of the dag arrays.
    //     function removeDagVoteOverDistForRisingAlone(address voter, uint256 dist, uint256 depth) internal {
    //         // we need to remove all votes that are not in the subtree of the voter
    //         // sent trianlge moves down
    //         // rec triangle moves up
    //         for ( uint256 i = 0; i < depth; i++){
    //             removeSentDagVoteLineDepthEqualsValue(voter,  i+1);
    //             removeRecDagVoteLineDistEqualsDepthPlusValue(voter, i);
    //         }

    //         sentDagVoteDepthDiff[voter] += depth;
    //         recDagVoteDepthDiff[voter] -= depth;

    //     }

    //     // we remove the rows on the edges and change the frame of the dag arrays.
    //     function removeDagVoteOverDistForFallingAlone(address voter, uint256 dist, uint256 depth) internal {
    //         // we need to remove all votes that are not in the subtree of the voter
    //         // sent trianlge moves up
    //         // rec triangle moves down

    //         for ( uint256 i = 0; i < depth; i++){
    //             removeSentDagVoteLineDistEqualsDepthPlusValue(voter, 0);
    //             removeRecDagVoteLineDepthEqualsValue(voter, 1);
    //         }

    //         sentDagVoteDepthDiff[voter] -= depth;
    //         recDagVoteDepthDiff[voter] += depth;
    //     }

    ///////////// Volume removals, across multiple voters on a branch

    //     ///////////// move alone
    //         ///// move to new recipient Alone
    //     ///////////// move with descendants
    //         //// JOIN THESE THREE INTO A SINGLE JUMP WITH DESCENDANTS FUNCTION

    //         // to change a tree vote to recipient, who is at most maxDistance away from voter.
    //         /////////// CURRENTLY NOT USED
    //                 function changeTreeVoteSameHeightWithDescendants(address voter, address recipient, uint256 maxDistance) internal {
    //                     (, uint256 depth) = findRelDepth(voter, recipient);
    //                     assert (depth == 1);

    //                     (, uint256 distance) = findDistAtSameDepth(treeVote[voter], recipient, maxDistance);

    //                     assert (distance <= maxDistance);

    //                     removeSentDagVoteJumpingTogether(voter, distance, 0);

    //                     removeTreeVote(voter);
    //                     addTreeVote(voter, recipient);

    //                 }
    //         /////////// CURRENTLY NOT USED END

    //         // equivalent to changing our tree vote to our parent's parent
    //         function changeTreeVoteRiseWithDescendants(address voter) internal {
    //             address recipient = treeVote[treeVote[voter]];
    //             assert (recipient != address(0));
    //             assert (recipient != address(1));

    //             removeDagVoteRisingTogether(voter, 0);

    //             removeTreeVote(voter);
    //             addTreeVote(voter, recipient);
    //         }

    //         /// CURRENTLY NOT USED
    //         // equivalent to changing our tree vote to our brother = parent's child
    //                     function changeTreeVoteFallWithDescendants(address voter, address recipient) internal {
    //                         assert (treeVote[recipient] == treeVote[voter]);
    //                         assert (treeVote[recipient]!= address(0));
    //                         assert (treeVote[recipient]!= address(1));

    //                         removeDagVoteFallingTogether(voter, 0);

    //                         removeTreeVote(voter);
    //                         addTreeVote(voter, recipient);
    //                     }
    //         /// CURRENTLY NOT USED END

    //  if (isAnscestor){
    //             handleDagVoteMoveFall(voter, recipient, address(0), lowerDist, lowerDepth);
    //             // for (uint256 depth=lowerDepth; 0<depth; depth--){
    //             //     address replacer = findNthParent(recipient, depth-1);
    //             //     handleDagVoteForFalling(voter, replacer);
    //             //     handleDagVoteForRising(replacer);
    //             //     switchTreeVoteWithParent(replacer);
    //             // }

    //             // sent removing columns that are too far away
    //             // sent falling
    //             // sent collapsing or sorting not needed, we get further from everyone

    //             // rec remove rows that are lower than lowerDepth+1
    //             // rec falling, here we also fall right.
    //             // rec no collapse needed, we don't get unequally futher from anyone
    //             // rec sorting, left coloumns, one for each descendant we fall under, some become closer descendants, some don't.

    //         } else if (isLowerOrEqual){
    //             // sent removing columns that are too high

    //             // sentDag Array falling

    //             // collapse bottomleft small triangle into a column
    //             // sort this column

    //             // rec Dag Array higher rows (higher than MRD- jump dist) need to be emptied.
    //             // rec Dag Arrau lower rows lower than lowerDepth
    //             // rec Dag Array needs lowering, right and down
    //             // rec collapse bottom left rectangle (the triangle cap on top has been removed) needs to be collapsed right.
    //             // rec sort the column we collapsed into.

    //         } else if (isSimilar){
    //             // here we are automatically not falling, as isLowerOrEqual is false.

    //             // sentDagVote
    //             // remove rows with depth under simDepth
    //             for (uint256 depth =1; depth < simDepth; depth++){
    //                 removeSentDagVoteLineDepthEqualsValue(voter, depth);
    //             }

    //             // rising
    //             increaseSentDagVoteDepthDiff(voter, simDepth-1);
    //             increaseSentDagVoteDistDiff(voter, simDepth-1);
    //             decreaseDistDepthFromSentOnOp(voter, simDepth-1, simDepth-1);

    //             //collapseSentDagVoteIntoColumn(voter, );
    //             // for each depth cell in the collapsed column
    //                 //sortSentDagVoteFromColumn(voter, ); by specifiyng the depth parent, we can calculate the dist based on that.

    //             // recDagVote
    //             // remove higher rows (higher than MRD-jump dist) need to be emptied.
    //             for (uint256 depth =MAX_REL_ROOT_DEPTH - simDist; depth <=MAX_REL_ROOT_DEPTH; depth++){
    //                 removeRecDagVoteLineDepthEqualsValue(voter, depth);
    //             }

    //             // here we need to collapse the left hand rectangle (cap has been emptied) into a right column first
    //             // rising,

    //             // now we sort the coloumn we collapsed into, by depth .

    //         } else if ((isHigher) && (higherDepthDiff > 1)){

    //             // remove rows with depth under higherDepthDiff
    //             for (uint256 depth =1; depth < higherDepthDiff; depth++){
    //                 removeSentDagVoteLineDepthEqualsValue(voter, depth);
    //             }

    //             // because of the rising, we need to change the graph.
    //             increaseSentDagVoteDepthDiff(voter, higherDepthDiff-1);
    //             increaseSentDagVoteDistDiff(voter, higherDepthDiff-1);
    //             decreaseDistDepthFromSentOnOp(voter, higherDepthDiff-1, higherDepthDiff-1);

    //             // collapseSentDagVoteIntoColumn(voter, );
    //             //sorting not required, as we are out of our original tree, so we cannot jump closer.

    //             // rec dag array needs to be emptied completely.
    //             removeRecDagVoteComplete(voter);

    //         }  else {
    //             // we jumped out completely, remove all votes.
    //             removeSentDagVoteComplete(voter);
    //             removeRecDagVoteComplete(voter);
    //         }

    // function handleDagVoteForFalling(address voter, address replacer) internal {

    //     removeSentDagVoteLineDistEqualsValue(voter, MAX_REL_ROOT_DEPTH);
    //     decreaseSentDagVoteDepthDiff(voter, 1);
    //     decreaseSentDagVoteDistDiff(voter, 1);
    //     // at this point the triangle is in its new position.
    //     increaseDistDepthFromSentOnOp(voter, 1, 1);

    //     // splitRecDagVoteDiagonal(voter, replacer);
    //     removeRecDagVoteLineDepthEqualsValue(voter, 1);
    //     increaseRecDagVoteDepthDiff(voter, 1);
    //     // decreaseDistDepthFromRecOnOp(voter, 0, 1);
    // }

    // function handleDagVoteForRising(address voter) internal {
    //     removeSentDagVoteLineDepthEqualsValue(voter, 1);
    //     increaseSentDagVoteDepthDiff(voter, 1);
    //     increaseSentDagVoteDistDiff(voter, 1);
    //     // at this point the triangle is in its new position.
    //     decreaseDistDepthFromSentOnOp(voter, 1, 1);

    //     // remove top right triangle
    //     // merge diagonal parallelogram into column
    //     // mergeRecDagVoteDiagonal(voter);
    //     decreaseRecDagVoteDepthDiff(voter, 1);
    //     // increaseDistDepthFromRecOnOp(voter, 0, 1);
    // }

    /////////// merge split
    // merge recDagVoteCell on diagonal right
    function mergeRecDagVoteDiagonalCell(address recipient, uint256 rdist) public {
        //     if (readRecDagVoteCount(recipient, rdist, rdist) == 0) {
        //         return;
        //     }
        //     for (uint256 i = readRecDagVoteCount(recipient, rdist, rdist); 1 <= i; i--) {
        //         DagVote memory rDagVote = readRecDagVote(recipient, rdist, rdist, i-1);
        //         safeRemoveRecDagVoteAtDistDepthPos(recipient, rdist, rdist, i-1);
        //         combinedDagAppend(rDagVote.id, recipient, rdist+1, rdist, rDagVote.weight);
        //         sentDagVoteTotalWeight[rDagVote.id] += rDagVote.weight;
        //     }
    }

    function splitRecDagVoteDiagonalCell(address recipient, uint256 dist, address checkAnscestor) public {
        //     if (readRecDagVoteCount(recipient, dist, dist) == 0) {
        //         return;
        //     }
        //     for (uint256 i = readRecDagVoteCount(recipient, dist, dist);  1<=i ; i--) {
        //         DagVote memory rDagVote = readRecDagVote(recipient, dist, dist, i-1);
        //         if (findNthParent(rDagVote.id, dist-1) == checkAnscestor){
        //             safeRemoveRecDagVoteAtDistDepthPos(recipient, dist, dist, i-1);
        //             // this is over the diagonal, but we will push the frame up
        //             combinedDagAppend(rDagVote.id, recipient, dist-1, dist, rDagVote.weight);
        //             sentDagVoteTotalWeight[rDagVote.id] += rDagVote.weight;
        //         }
        //     }
    }

    // function mergeRecDagVoteDiagonal(address recipient) public {
    //     // for (uint256 i = 1; i < MAX_REL_ROOT_DEPTH; i++) {
    //     //     mergeRecDagVoteDiagonalCell(recipient, i);

    //     // }
    //     // removeRecDagVoteCell(recipient, MAX_REL_ROOT_DEPTH, MAX_REL_ROOT_DEPTH);
    // }

    // function splitRecDagVoteDiagonal(address recipient, address checkAnscestor) public {
    //     // for (uint256 i = 2; i <= MAX_REL_ROOT_DEPTH; i++) {
    //     //     splitRecDagVoteDiagonalCell(recipient, i, checkAnscestor);
    //     // }
    // }
}
