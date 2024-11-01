use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, find_input,
}
use types/automatic_payments.{Settings}
use types/settings.{settings_nft_name} as settings_types

/// The settings validator lets the settings and treasury admins update global settings for the protocol
///
/// It is parameterized by the protocol_boot_utxo, a constant to make it an NFT by the usual trick.
validator settings(protocol_boot_utxo: OutputReference) {
  spend(
    datum: Option<Settings>,
    _redeemer: Data,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(input_datum) = datum
    // Find our own input so we know the datum / our own address
    expect Some(own_input) = find_input(tx.inputs, own_ref)
    let own_address = own_input.output.address

    // Then find our continuing output;
    // We can assume the first output is the settings output
    // This is safe because the ledger doesn't reorder the outputs,
    // and if someone constructs it out of order, it'll just fail because the address / value will change
    // since the NFT is unique
    expect Some(own_output) = list.head(tx.outputs)
    expect own_output.address == own_address
    // It's also important to enforce that this is an inline datum;
    // setting a datum hash could cause a bunch of off-chain infrastructure to break
    expect InlineDatum(output_datum) = own_output.datum
    expect output_datum: Settings = output_datum

    let valid_output_datum =
      input_datum.setting_admin_pkh == output_datum.setting_admin_pkh

    // We check that the value on the input and output are equal, to ensure the settings NFT gets paid back into the output
    // We compare `without_lovelace` to leave full freedom for ADA to be added/removed as the minUTXO requirement changes
    // Note that this can only be spent by the SettingsAdmin or TreasuryAdmin, so we won't leak a small amount of ADA to arbitrary users
    // Also, it is not expected that the ADA ever be more than the minUTXO cost, so this doesn't expose hundreds of ADA (for example) to the treasury admin
    let value_not_changed =
      assets.without_lovelace(own_output.value) == assets.without_lovelace(
        own_input.output.value,
      )

    // Make sure we don't mint anything, otherwise someone might mint another settings token
    let no_mint = tx.mint == assets.zero

    let signed_by_admin =
      list.has(tx.extra_signatories, input_datum.setting_admin_pkh)

    and {
      valid_output_datum,
      signed_by_admin,
      value_not_changed,
      no_mint,
    }
  }

  // Let us mint the settings NFT exactly once, by checking that one of the inputs is the protocol_boot_utxo
  mint(_redeemer: Data, own_policy_id: PolicyId, tx: Transaction) {
    let expected_mint = assets.from_asset(own_policy_id, settings_nft_name, 1)
    // Check that we mint *only* one token, and it's exactly our own policy id, and the settings NFT name
    // This ensures that we don't sneakily mint a second NFT for "reasons"
    let mints_exactly_one_settings_nft = tx.mint == expected_mint

    // And, like mentioned above, ensure that this is a true NFT
    let spends_protocol_boot_utxo =
      list.any(
        tx.inputs,
        fn(input) { input.output_reference == protocol_boot_utxo },
      )

    // Make sure the output value contains no extra tokens, and is paid to the settings script itself
    expect [settings_output] =
      list.filter(
        tx.outputs,
        fn(output) { assets.without_lovelace(output.value) == expected_mint },
      )

    let pays_to_settings_script =
      settings_output.address.payment_credential == Script(own_policy_id)
    // Make sure the datum is an inline datum, and has a well-formed datum
    expect InlineDatum(settings_datum) = settings_output.datum
    expect _: Settings = settings_datum

    // TODO: require a signature from the 3 initial admins (or at least the settings admin) to prevent bricking?
    and {
      mints_exactly_one_settings_nft?,
      spends_protocol_boot_utxo?,
      pays_to_settings_script?,
    }
  }

  else(_) {
    fail
  }
}
