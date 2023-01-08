// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract AnthillUnused {
    //     // to remove non-local votes when jumping distance and depth under the jumper.  
    //     // currently not used, so internal 
    //     function removeSentDagVoteJumpingTogether(address voter, uint32 jumpDistance, uint32 depth) internal {
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
    //         for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
    //             address recipient = recTreeVote[voter][i];
    //             removeSentDagVoteJumpingTogether(recipient, jumpDistance, depth+1);
    //         }
    //     }



    //     // when rising a single depth up the tree,
    //     function removeDagVoteRisingTogether(address voter, uint32 depth) internal {
    //         if (MAX_REL_ROOT_DEPTH<= depth){
    //             return;
    //         }
    //         //////////// Wrong!!!! the triangle's right half, i.e. voters over dist, move up or down. 

    //         removeDagVoteForRisingAlone(voter, depth);

    //         for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
    //             address recipient = recTreeVote[voter][i];
    //             removeDagVoteRisingTogether(recipient, depth+1);
    //         }
    //     }

    

    //     // when falling a single depth to one of our brothers,
    //     function removeDagVoteFallingTogether(address voter, uint32 depth) internal {
    //         if (MAX_REL_ROOT_DEPTH<= depth){
    //             return;
    //         }
            
    //         removeDagVoteForFallingAlone(voter, depth);

    //         for (uint32 i =0; i< recTreeVoteCount[voter]; i++) {
    //             address recipient = recTreeVote[voter][i];
    //             removeDagVoteFallingTogether(recipient, depth+1);
    //         }
    //     }


    //   function removeSentDagVoteLineDistEqualsDepthPlusValue(address voter, uint32 value) internal {
    //             for (uint32 i = value+1; i <= MAX_REL_ROOT_DEPTH; i++) {
    //                 removeSentDagVoteCell(voter, i, i-value);
    //             }
    //         }

    //         function removeRecDagVoteLineDistEqualsDepthPlusValue(address voter, uint32 value) internal {
    //             for (uint32 i = value+1; i <= MAX_REL_ROOT_DEPTH; i++) {
    //                 removeRecDagVoteCell(voter, i, i-value);
    //             }
    //         }

    //  function removeRecDagVoteLineDistEqualsValue(address voter, uint32 value) internal {
    //             for (uint32 i = 1; i <= value; i++) {
    //                 removeSentDagVoteCell(voter, value, i);
    //             }
    //         }  

    //  function changeDistDepthSent(address voter, uint32 dist, uint32 depth, uint32 sPos, address recipient, uint32 rPos, uint32 weight, uint32 newDist, uint32 newDepth) internal{
    //             // here it is ok to use unsafe, as the the vote is moved, not removed
    //             unsafeReplaceSentDagVoteAtDistDepthPosWithLast(voter, dist, depth, sPos);                
    //             sentDagAppend(voter, newDist, newDepth, recipient, weight, rPos);
    //         }



     // ///////////// Area removals, for single voters, across both tables
    //     // to remove all votes over a given distance from the DagVote arrays, and the corresponding votes from the DagVote arrays
    //     function removeDagVoteForJumpingAlone(address voter, uint32 dist) internal {
    //         for (uint32 i = dist; i < MAX_REL_ROOT_DEPTH; i++) {
    //             removeSentDagVoteLineDistEqualsValue(voter, sentDagVoteDepthDiff[voter]+ i);
    //             removeRecDagVoteLineDistEqualsValue(voter, recDagVoteDepthDiff[voter]+ i);
    //         }
    //     }

    //     // we remove the rows on the edges and change the frame of the dag arrays. 
    //     function removeDagVoteOverDistForRisingAlone(address voter, uint32 dist, uint32 depth) internal {
    //         // we need to remove all votes that are not in the subtree of the voter
    //         // sent trianlge moves down
    //         // rec triangle moves up
    //         for ( uint32 i = 0; i < depth; i++){
    //             removeSentDagVoteLineDepthEqualsValue(voter,  i+1);
    //             removeRecDagVoteLineDistEqualsDepthPlusValue(voter, i);
    //         }
            
    //         sentDagVoteDepthDiff[voter] += depth;
    //         recDagVoteDepthDiff[voter] -= depth;
        
    //     }

    //     // we remove the rows on the edges and change the frame of the dag arrays.
    //     function removeDagVoteOverDistForFallingAlone(address voter, uint32 dist, uint32 depth) internal {
    //         // we need to remove all votes that are not in the subtree of the voter
    //         // sent trianlge moves up
    //         // rec triangle moves down

    //         for ( uint32 i = 0; i < depth; i++){
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
//                 function changeTreeVoteSameHeightWithDescendants(address voter, address recipient, uint32 maxDistance) internal {
//                     (, uint32 depth) = findRelDepth(voter, recipient);
//                     assert (depth == 1);

//                     (, uint32 distance) = findDistAtSameDepth(treeVote[voter], recipient, maxDistance);

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
   
}