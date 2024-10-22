use aiken/cbor
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace bytearray.to_hex(
    cbor.serialise(
      OutputReference(
        #"db1133ee20002ad7de8c3c1e5348c21decfd5f3474a4bf9124eab31fd04180ec",
        1,
      ),
    ),
  )
  True
}
