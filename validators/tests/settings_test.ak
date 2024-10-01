use aiken/cbor
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace bytearray.to_hex(
    cbor.serialise(
      OutputReference(
        #"f7ab6de61468c99e2112919ba48e9717fd219c4a98e5958992214bb715274ead",
        0,
      ),
    ),
  )
  True
}
