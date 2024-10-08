use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}

pub type AssetAmount {
  policy_id: PolicyId,
  asset_name: AssetName,
  amount: Int,
}

pub type AutomatedPayment {
  // The funds owner: payment credentials used to cancel order
  // Optional stake credentials to create and maintain franken address  
  owner: Address,
  /// Value to sent periodically
  amount_to_send: List<AssetAmount>,
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
