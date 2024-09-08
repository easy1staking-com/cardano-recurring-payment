use aiken/bytearray
use aiken/cbor
use aiken/transaction.{OutputReference, TransactionId}

const tx_hash_id =
  #"aadaac3863a0e43da3f4464c2fdccada8d39ffe3a041e01fc5849e8a720e9cf3"

const output_index = 0

test serialise_bootstrap_utxo() {
  let output_reference =
    OutputReference(TransactionId(tx_hash_id), output_index)
  let output_reference_cbor = cbor.serialise(output_reference)
  let serialised_bootstrap_utxo = bytearray.to_hex(output_reference_cbor)
  trace serialised_bootstrap_utxo
  True
}
