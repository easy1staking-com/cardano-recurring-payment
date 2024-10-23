use aiken/cbor
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace bytearray.to_hex(
    cbor.serialise(
      OutputReference(
        #"f57f6f626f43a026a11654f4ee88b5f4ef52166b0a2083fe2ed1d822e6045b80",
        1,
      ),
    ),
  )
  True
}
