const {
  Pact,
  isSignedTransaction,
  createClient,
  signWithChainweaver } = require('@kadena/client');

const fs = require('fs');

const NETWORK_ID = 'testnet04';
const CHAIN_ID = '1';
const API_HOST = `https://api.testnet.chainweb.com/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;
const CONTRACT_PATH = './cal.pact';
const ACCOUNT_NAME = 'k:49387cb32906bc3cf5e2fdae3cf4e506edd859d6a05b33e4c33374ec3ecd92c5';
const PUBLIC_KEY = '49387cb32906bc3cf5e2fdae3cf4e506edd859d6a05b33e4c33374ec3ecd92c5';

// k:49387cb32906bc3cf5e2fdae3cf4e506edd859d6a05b33e4c33374ec3ecd92c5

const pactCode = fs.readFileSync(CONTRACT_PATH, 'utf8');

deployContract();

// async function deployContract(pactCode) {
//   const publicMeta = {
//     ttl: 28000,
//     gasLimit: 100000,
//     chainId: CHAIN_ID,
//     gasPrice: 0.000001,
//     sender: ACCOUNT_NAME // the account paying for gas
//   };
//   const pactCommand = new PactCommand()
//     .setMeta(publicMeta, NETWORK_ID)
//     .addCap('coin.GAS', PUBLIC_KEY)
//     .addData({
//       'election-admin-keyset': [PUBLIC_KEY],
//       upgrade: false
//     });
//   pactCommand.code = pactCode;

//   const signedTransaction = await signWithChainweaver(pactCommand);

//   const response = await signedTransaction[0].send(API_HOST);
//   console.log(response);
// }


async function deployContract() {
  const transaction = Pact.builder
    .execution(pactCode)
    .setMeta({
      ttl: 28800,
      gasLimit: 100000,
      gasPrice: 0.00000001,
      senderAccount: ACCOUNT_NAME,
      chainId: CHAIN_ID,
    })
    .setNetworkId(NETWORK_ID)
    .addSigner(PUBLIC_KEY)
    // .addData('election-admin-keyset', { keys: [PUBLIC_KEY], pred: 'keys-all' })
    // .addData('upgrade', false)
    .createTransaction();
  const signedTx = await signWithChainweaver(transaction);
  // do a preflight/dirtyRead first to check if the request is successful. it provides fast feedback and prevents loss of gas in case of a failing transaction
  // const preflightResponse = await client.preflight(signedTx);
  // console.log(preflightResponse)

  if (isSignedTransaction(signedTx)) {
    const client = createClient(API_HOST);
    const transactionDescriptor = await client.submit(signedTx);
    const response = await client.listen(transactionDescriptor, {});
    if (response.result.status === 'failure') {
      throw response.result.error;
    } else {
      console.log(response.result);
    }
  }
}

