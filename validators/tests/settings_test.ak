use aiken/cbor
use aiken/primitive/bytearray
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace bytearray.to_hex(
    cbor.serialise(
      OutputReference(
        #"8cac3945ed9866f45b2c7c2759c95d65b2d768e1c6596790156efbbdaa69e893",
        1,
      ),
    ),
  )
  True
}
