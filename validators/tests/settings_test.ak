use aiken/cbor
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace bytearray.to_hex(
    cbor.serialise(
      OutputReference(
        #"3ebc6e0541f3fb6710c6bd3ba2f887c7c949b45d8c21d49ed36bb3aac7d2b172",
        0,
      ),
    ),
  )
  True
}
