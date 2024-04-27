# anthill
## intro 
Disclaimer: Demo app.

Anthill is a liquid democracy inspired reputation system, people are organised into a binary tree, and everyone is assigned a reputation (number).

The position does not directly affect the reputation. You get reputation by collecting secondary value votes. You can give anyone value votes above you in the tree, within a certain proximity. Similarly, you can receive value votes form anyone under you, in a certain proximity.

To emphasise: value votes, and not position determines your reputation.

Also you can leave the tree, or move to unoccupied spots in the tree.

Finally: if you have higher reputation than your parent in the binary tree, you can change positions with them, thus climbing the tree.

This is the repo for the smart contracts.

## development 

To build and test use forge. For local development with backend and frontend deploy the smart contract on anvil with:

anvil --chain-id 1337

forge script script/Anthill.s.sol:SmallScript --broadcast --verify --rpc-url http://localhost:8545  

After this the backend can be launched with:

npm run start:dev

And the frontend can be launched with:

npm start

If using metamask you have to clear metamask activity between different anvil sessions, as nonce and other things might change. Do this is setting-> advanced -> reset account

### deployment
smart contract need to be deployed, and the address has to be set in the frontend, backend
heroku builds backend based on github's main branch
firebase frontend does not build on github yet, I should do that. But currently npm run build and firebase deploy deploys the frontend.

### zksync specific development

On main 2024/04/27
- install zk forge 
- remove Anthill from  zkout folder, AnthillInner address from foundry.toml
- start zksync local node
- ```../../zksync/fzksync/foundry-zksync/target/release/zkforge zkbuild  --contracts-to-compile src/AnthillInner.sol```
- To find missing libraries: 
    ``` ../../zksync/fzksync/foundry-zksync/target/release/zkforge zkbuild ```
-  To deploy missing libraries: 
    ```../../zksync/fzksync/foundry-zksync/target/release/zkforge zkcreate --deploy-missing-libraries --private-key 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110  --rpc-url http://localhost:8011 --chain 260 ```
- To build properly: 
    ``` ../../zksync/fzksync/foundry-zksync/target/release/zkforge zkbuild ```

Now you can run tests

