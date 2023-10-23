import {
    createClient, createSignWithKeypair, isSignedTransaction, Pact, signWithChainweaver,
} from "@kadena/client";

// const NETWORK_ID = 'testnet04';
// const CHAIN_ID = '1';
// const API_HOST = `https://api.testnet.chainweb.com/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;
// const ACCOUNT_NAME = 'k:49387cb32906bc3cf5e2fdae3cf4e506edd859d6a05b33e4c33374ec3ecd92c5';
// const PUBLIC_KEY = '49387cb32906bc3cf5e2fdae3cf4e506edd859d6a05b33e4c33374ec3ecd92c5';

const NETWORK_ID = 'fast-development';
const CHAIN_ID = '0';
const API_HOST = `http://localhost:8080/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;
const ACCOUNT_NAME = 'k:0e56f785b12b47a93ce09a1360466e17d986d352b244da7b67bd2af87fdbcd88';
const PUBLIC_KEY = '0e56f785b12b47a93ce09a1360466e17d986d352b244da7b67bd2af87fdbcd88';
// {
//     "keyset": {
//         "pred": "keys-all",
//         "keys": [
//             "0e56f785b12b47a93ce09a1360466e17d986d352b244da7b67bd2af87fdbcd88"
//         ]
//     },
//     "account": "k:0e56f785b12b47a93ce09a1360466e17d986d352b244da7b67bd2af87fdbcd88",
//     "chain": "0"
// }

add();
async function add() {
    const transaction = Pact.builder
        .execution('(free.repl-academy-cal.add 2 3)')
        .setMeta({
        ttl: 28800,
        gasLimit: 100000,
        gasPrice: 0.00000001,
        senderAccount: ACCOUNT_NAME,
        chainId: CHAIN_ID,
      })
      .setNetworkId(NETWORK_ID)
      .addSigner(PUBLIC_KEY)
      .createTransaction();

    
    //   const signedTx = await signWithChainweaver(transaction);

    const signWithKeypair = createSignWithKeypair({
        publicKey: PUBLIC_KEY,
        secretKey: "251a920c403ae8c8f65f59142316af3c82b631fba46ddea92ee8c95035bd2898",
      });
    
      const signedTx = await signWithKeypair(transaction);
      
    if (isSignedTransaction(signedTx)) {
        console.log('transaction has been signed');
        const client = createClient(API_HOST);
        const transactionDescriptor = await client.submit(signedTx);
        const response = await client.listen(transactionDescriptor);

        if (response.result.status === 'failure') {
            throw response.result.error;
        } else {
            console.log(response.result)
        }
    }
}