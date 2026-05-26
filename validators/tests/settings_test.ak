use aiken/cbor
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace bytearray.to_hex(
    cbor.serialise(
      OutputReference(
        #"8c198e942f1f7a60e704aa1651333b45bccd51653259204e4dac38b559844dd8",
        0,
      ),
    ),
  )
  True
}
