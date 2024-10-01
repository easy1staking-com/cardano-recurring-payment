use aiken/cbor
use cardano/transaction.{OutputReference}

test serialise_bootstrap_utxo() {
  trace cbor.serialise(
    OutputReference(
      #"dfa5892f4623b8fbe0aaab204b33c93bab0bb6a8e655d1b61aa333222fac7c64",
      0,
    ),
  )
  True
}
