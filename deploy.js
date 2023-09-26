const { PactCommand, signWithChainweaver  } = require('@kadena/client');
const fs = require('fs');

const NETWORK_ID = 'testnet04';
const CHAIN_ID = '0';
const API_HOST = `https://api.testnet.chainweb.com/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;
const CONTRACT_PATH = './token.pact';
const ACCOUNT_NAME = 'k:f4949167c46f0baf4c40002d231b5bd0de536f993a3a13863781ee638dbe5a2b';
const PUBLIC_KEY = 'f4949167c46f0baf4c40002d231b5bd0de536f993a3a13863781ee638dbe5a2b';

const pactCode = fs.readFileSync(CONTRACT_PATH, 'utf8');

deployContract(pactCode);

async function deployContract(pactCode) {
  const publicMeta = {
    ttl: 28000,
    gasLimit: 100000,
    chainId: CHAIN_ID,
    gasPrice: 0.000001,
    sender: ACCOUNT_NAME // the account paying for gas
  };
  const pactCommand = new PactCommand()
    .setMeta(publicMeta, NETWORK_ID)
    .addCap('coin.GAS', PUBLIC_KEY)
    .addData( {
      'election-admin-keyset': [ PUBLIC_KEY ],
      'upgrade': false
    });
  pactCommand.code = pactCode;

  const signedTransaction = await signWithChainweaver(pactCommand);

  const response = await signedTransaction[0].send(API_HOST);
  console.log(response);
};