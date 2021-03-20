# ETHMaxiToken

Here's how it works:

1. Contract gets deployed, stores a reference to the previous block hash.
2. Someone provides a small proof that pulls out the state root.
3. Now other people can start executing account proofs against the state root.
4. People claim balances by providing a proof of their ETH balance at the state root.
5. Your balance can be slashed if someone provides a proof that you signed a transaction with a chain ID other than 1 (= ethereum).

Enjoy! I probably won't deploy this, but feel free to do it if you want to get it audited.
