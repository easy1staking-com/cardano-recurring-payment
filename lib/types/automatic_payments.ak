use aiken/hash.{Blake2b_224, Hash}
use aiken/time.{PosixTime}
use aiken/transaction/credential.{
  PaymentCredential, StakeCredential, VerificationKey,
}
use aiken/transaction/value.{AssetName, PolicyId}

pub type Datum {
  /// The funds owner 
  owner_payment_pkh: Hash<Blake2b_224, VerificationKey>,
  /// The optional (?) stake address of the sender mingled address
  owner_stake_pkh: Option<StakeCredential>,
  /// Value to sent periodically
  amount_to_send: List<(PolicyId, AssetName, Int)>,
  /// Destination address Payment pub key
  payee_payment_credential: PaymentCredential,
  /// Destination address Staking pub key (optional)
  payee_stake_credential: Option<StakeCredential>,
  /// Starting Date Time. Namely time of the first payment should be made
  start_time: PosixTime,
  /// If specified, no more payments must be made after end date. This can be used to determine how many payments to make (start_time + (N + 1) * payment_frequency)
  end_time: Option<PosixTime>,
  // How often to perform a payment
  payment_frenquency: PaymentFrenquency,
  // Maximum delay to perform payment within a period. Expressed in hours.
  max_payment_delay_hours: Option<Int>,
}

pub type Redeemer {
  Withdraw
  ExecutePayment
}

pub type PaymentFrenquency {
  Hourly
  Hours { hours: Int }
  Daily
  Days { days: Int }
  Weekly
  Weeks { weeks: Int }
  Yearly
}

pub type Configuration {
  // BOT Payment PKH
  bot_payment_pkh: Hash<Blake2b_224, VerificationKey>,
  bot_fee_lovelaces: Int,
}
