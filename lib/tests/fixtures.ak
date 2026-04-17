use cardano/address
use cardano/assets
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use oracle.{AggState, Charli3OracleDatum, GenericData}
use types/automatic_payments.{AutomatedPayment, FixedAmount, OracleConfig,
  OraclePricedAmount}

pub fn datum_template() {
  AutomatedPayment(
    #"",
    FixedAmount { assets: [] },
    address.from_verification_key(#""),
    1719835200000,
    None,
    Some(1),
    None,
    1_000_000,
  )
}

pub fn oracle_datum_template(oracle_nft_policy_id: ByteArray) {
  AutomatedPayment(
    #"",
    OraclePricedAmount {
      oracle_config: OracleConfig {
        oracle_nft_policy_id,
        target_amount: 100_000_000,
        payment_policy_id: #"",
        payment_asset_name: #"",
        max_price_age_ms: None,
        min_price: None,
        max_price: None,
      },
    },
    address.from_verification_key(#""),
    1719835200000,
    None,
    Some(24),
    None,
    2_000_000,
  )
}

/// Build a Charli3 oracle reference input with the given price, creation time,
/// and expiration time. The oracle NFT is (oracle_nft_policy_id, "C3AS").
pub fn oracle_ref_input(
  oracle_nft_policy_id: ByteArray,
  price: Int,
  creation_time: Int,
  expiration_time: Int,
) -> Input {
  let oracle_datum: Charli3OracleDatum =
    AggState(
      GenericData {
        price_map: [
          Pair(0, price),
          Pair(1, creation_time),
          Pair(2, expiration_time),
        ],
      },
    )

  Input {
    output_reference: OutputReference(#"cc", 0),
    output: Output {
      address: address.from_script(#"dd"),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(oracle_nft_policy_id, "C3AS", 1),
      datum: InlineDatum(oracle_datum),
      reference_script: None,
    },
  }
}
