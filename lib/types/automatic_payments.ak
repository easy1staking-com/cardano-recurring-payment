use aiken/crypto.{Blake2b_224, Hash, VerificationKey, VerificationKeyHash}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}

pub type AssetAmount {
  policy_id: PolicyId,
  asset_name: AssetName,
  amount: Int,
}

/// Charli3 oracle feed configuration for oracle-priced payments.
pub type OracleConfig {
  /// PolicyId of the Charli3 oracle NFT (varies per price pair).
  oracle_nft_policy_id: PolicyId,
  /// Target amount in the pricing currency, scaled by 1e6.
  /// e.g., 100_000_000 = $100
  target_amount: Int,
  /// PolicyId of the asset to actually send ("" for ADA).
  payment_policy_id: PolicyId,
  /// AssetName of the asset to actually send ("" for ADA).
  payment_asset_name: AssetName,
  /// Optional max acceptable age of the oracle price in milliseconds.
  max_price_age_ms: Option<Int>,
  /// Optional price floor (scaled by 1e6). Rejects if price below.
  min_price: Option<Int>,
  /// Optional price ceiling (scaled by 1e6). Rejects if price above.
  max_price: Option<Int>,
}

/// How the payment amount is determined.
pub type PaymentAmount {
  /// Fixed: send exactly these assets (existing behavior).
  FixedAmount { assets: List<AssetAmount> }
  /// Oracle-priced: compute amount from Charli3 oracle at execution time.
  OraclePricedAmount { oracle_config: OracleConfig }
}

pub type AutomatedPayment {
  // The funds owner: payment credentials used to cancel order
  // Optional stake credentials to create and maintain franken address
  owner_pkh: VerificationKeyHash,
  /// How much to send: fixed assets or oracle-computed amount
  amount_to_send: PaymentAmount,
  /// Destination address Payment pub key
  payee: Address,
  /// Starting Date Time. Namely time of the first payment should be made
  start_time: Int,
  /// If specified, no more payments must be made after end date. This can be used to determine how many payments to make (start_time + (N + 1) * payment_frequency)
  end_time: Option<Int>,
  /// How often to perform a payment
  payment_interval_hours: Option<Int>,
  /// Maximum delay to perform payment within a period. Expressed in hours.
  max_payment_delay_hours: Option<Int>,
  /// max fee customer is willing to pay
  max_fees_lovelace: Int,
}

pub type Redeemer {
  Withdraw
  RescueFunds
  ExecutePayment {
    in_index: Int,
    num_batch_payments: Int,
    operator_index: Int,
    fee_exempt_user_index: Option<Int>,
  }
}

pub type Settings {
  // BOT Payment PKH
  setting_admin_pkh: Hash<Blake2b_224, VerificationKey>,
  authorised_operators: List<Hash<Blake2b_224, VerificationKey>>,
  operator_fee_exempt_users: List<Hash<Blake2b_224, VerificationKey>>,
  operator_fee_lovelace: Int,
  base_fee_lovelace: Int,
}
