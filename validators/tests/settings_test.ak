use aiken/bytearray
use aiken/cbor
use aiken/transaction.{OutputReference, TransactionId}

const tx_hash_id =
  #"bf5b1102d6ed7eb0e9cb1b3d82b34e0bbdf038c724cb69be7880a79c61012399"

const output_index = 0

test load_configuration_succeed() {
  trace @"Hello"
  let output_reference =
    OutputReference(TransactionId(tx_hash_id), output_index)
  trace @"World"
  let output_reference_cbor = cbor.serialise(output_reference)
  trace @"Foo"
  let bla = bytearray.to_hex(output_reference_cbor)
  trace bla
  True
}
