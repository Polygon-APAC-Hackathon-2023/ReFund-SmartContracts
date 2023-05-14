// Import the libraries and load the environment variables.
const { SDK, Auth, TEMPLATES, Metadata } = require('@infura/sdk') ;
require('dotenv').config()

// Create Auth object
const auth = new Auth({
      projectId: process.env.INFURA_API_KEY,
      secretId: process.env.INFURA_API_KEY_SECRET,
      privateKey: process.env.WALLET_PRIVATE_KEY,
      chainId: 80001,
});

// Instantiate SDK
const sdk = new SDK(auth);

(async() => {
    try {
      const newContractERC1155 = await sdk.deploy({
        template: TEMPLATES.ERC1155Mintable,
        params: {
          baseURI: "https://ikzttp.mypinata.cloud/ipfs/QmeBWSnYPEnUimvpPfNHuvgcK9wFH9Sa6cZ4KDfgkfJJis/",
          contractURI: "https://azuki-prereveal.s3-us-west-1.amazonaws.com/metadata/",
          ids: [0, 1],
        },
      });
      console.log('Contract: ', newContractERC1155.contractAddress);
    } catch (error) {
      console.log(error);
    }
})();
