use aiken/bytearray
use aiken/cbor
use aiken/transaction.{OutputReference, TransactionId}

const tx_hash_id =
  #"dfa5892f4623b8fbe0aaab204b33c93bab0bb6a8e655d1b61aa333222fac7c64"

const output_index = 0

test serialise_bootstrap_utxo() {
  let output_reference =
    OutputReference(TransactionId(tx_hash_id), output_index)
  let output_reference_cbor = cbor.serialise(output_reference)
  let serialised_bootstrap_utxo = bytearray.to_hex(output_reference_cbor)
  trace serialised_bootstrap_utxo
  True
}
