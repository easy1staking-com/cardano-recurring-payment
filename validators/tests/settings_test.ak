use aiken/bytearray
use aiken/cbor
use aiken/transaction.{OutputReference, TransactionId}

const tx_hash_id =
  #"4f79db6c5e935d243340c44ab53f51dc3e6dd1c1a859f22f862482397b6a9281"

const output_index = 0

test serialise_bootstrap_utxo() {
  let output_reference =
    OutputReference(TransactionId(tx_hash_id), output_index)
  let output_reference_cbor = cbor.serialise(output_reference)
  let serialised_bootstrap_utxo = bytearray.to_hex(output_reference_cbor)
  trace serialised_bootstrap_utxo
  True
}
