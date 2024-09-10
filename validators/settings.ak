use aiken/list
use aiken/transaction.{
  InlineDatum, Mint, Output, OutputReference, ScriptContext, Spend, find_input,
}
use aiken/transaction/credential.{ScriptCredential}
use aiken/transaction/value.{AssetName}
use types/automatic_payments.{Settings}

pub fn spent_output(ctx: ScriptContext) -> Output {
  expect Spend(out_ref) = ctx.purpose
  expect Some(input) = find_input(ctx.transaction.inputs, out_ref)
  input.output
}

/// The name of the token that authenticates the settings UTXO
pub const settings_nft_name: AssetName = "settings"

/// The settings validator lets the settings and treasury admins update global settings for the protocol
///
/// It is parameterized by the protocol_boot_utxo, a constant to make it an NFT by the usual trick.
validator(protocol_boot_utxo: OutputReference) {
  pub fn spend(input_datum: Settings, _: Data, ctx: ScriptContext) {
    // Find our own input so we know the datum / our own address
    let own_input = spent_output(ctx)
    let own_address = own_input.address

    // Then find our continuing output;
    // We can assume the first output is the settings output
    // This is safe because the ledger doesn't reorder the outputs,
    // and if someone constructs it out of order, it'll just fail because the address / value will change
    // since the NFT is unique
    expect Some(own_output) = list.head(ctx.transaction.outputs)
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
      value.without_lovelace(own_output.value) == value.without_lovelace(
        own_input.value,
      )

    // Make sure we don't mint anything, otherwise someone might mint another settings token
    let no_mint = value.from_minted_value(ctx.transaction.mint) == value.zero()

    let signed_by_admin =
      list.has(ctx.transaction.extra_signatories, input_datum.setting_admin_pkh)

    and {
      valid_output_datum,
      signed_by_admin,
      value_not_changed,
      no_mint,
    }
  }

  // Let us mint the settings NFT exactly once, by checking that one of the inputs is the protocol_boot_utxo
  pub fn mint(_r: Data, ctx: ScriptContext) {
    expect Mint(own_policy_id) = ctx.purpose

    let expected_mint = value.from_asset(own_policy_id, settings_nft_name, 1)
    // Check that we mint *only* one token, and it's exactly our own policy id, and the settings NFT name
    // This ensures that we don't sneakily mint a second NFT for "reasons"
    let mints_exactly_one_settings_nft =
      value.from_minted_value(ctx.transaction.mint) == expected_mint

    // And, like mentioned above, ensure that this is a true NFT
    let spends_protocol_boot_utxo =
      list.any(
        ctx.transaction.inputs,
        fn(input) { input.output_reference == protocol_boot_utxo },
      )

    // Make sure the output value contains no extra tokens, and is paid to the settings script itself
    expect [settings_output] =
      list.filter(
        ctx.transaction.outputs,
        fn(output) { value.without_lovelace(output.value) == expected_mint },
      )

    let pays_to_settings_script =
      settings_output.address.payment_credential == ScriptCredential(
        own_policy_id,
      )
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
}
