use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{
  Finite, Interval, IntervalBound, PositiveInfinity, after, intersection,
}
use aiken/list
use aiken/time.{PosixTime}
use aiken/transaction.{ScriptContext, ValidityRange}
use aiken/transaction/credential.{VerificationKey}

// use aiken/transaction/value.{Value}

// type PaymentFrenquency {
//   Hourly
//   Hours { hours: Int }
//   Daily
//   Days { days: Int }
//   Weekly
//   Weeks { weeks: Int }
//   Monthly
//   Months { months: Int }
//   Yearly
// }

type Datum {
  // The funds owner 
  owner_payment_pkh: Hash<Blake2b_224, VerificationKey>,
  // Value to sent periodically
  // amount_to_send: Value, // opaque type, to be replaced
  // Destination address Payment pub key
  destination_payment_pkh: Hash<Blake2b_224, VerificationKey>,
  // Destination address Staking pub key (optional)
  destination_staking_pkh_opt: Option<Hash<Blake2b_224, VerificationKey>>,
  // Starting Date Time. Namely time of the first payment should be made
  start_time: PosixTime,
  // How often to perform a payment
  // payment_frenquency: PaymentFrenquency,
  // Maximum delay to perform payment within a period. Expressed in hours.
  max_payment_delay_hours: Option<Int>,
  // BOT Payment PKH
  bot_payment_pkh: Hash<Blake2b_224, VerificationKey>,
}

type Redeemer {
  Withdraw { owner_payment_pkh: Hash<Blake2b_224, VerificationKey> }
  Spend
}

// fn isBotAllowed(self: Datum, )

// Sending funds must happen after a certain moment in time has passed, but also,
// if defined, a maximum delay has not passed.
// Example1: tx can be sent anytime after datum.start_time.
// Example2: tx can be sent anytime after datum.start_time, but before datum.max_payment_delay_hours
// have not passed after datum.start_time.
// In case of missing the payment slot, the bot is de facto stuck.
fn is_paymet_time_valid(self: Datum, validity_range: ValidityRange) -> Bool {
  let upper_bound =
    when self.max_payment_delay_hours is {
      Some(max_delay_hours) ->
        IntervalBound {
          bound_type: Finite(self.start_time + max_delay_hours * 60 * 60),
          is_inclusive: True,
        }
      None ->
        IntervalBound { bound_type: PositiveInfinity, is_inclusive: False }
    }
  let valid_transaction_range =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(self.start_time),
        is_inclusive: True,
      },
      upper_bound,
    }

  intersection(valid_transaction_range, validity_range) == validity_range
}

fn is_payment_time_valid_v2(self: Datum, validity_range: ValidityRange) -> Bool {
  let is_start_time_valid =
    when validity_range.lower_bound.bound_type is {
      Finite(tx_earliest_time) -> self.start_time <= tx_earliest_time
      _ -> False
    }

  let is_end_time_valid =
    when self.max_payment_delay_hours is {
      None -> True
      Some(max_delay_hours) ->
        when validity_range.upper_bound.bound_type is {
          Finite(tx_latest_time) ->
            tx_latest_time <= self.start_time + max_delay_hours * 60 * 60
          _ -> False
        }
    }
  is_start_time_valid && is_end_time_valid
}

validator {
  fn automatic_payments(
    datum: Datum,
    redeemer: Redeemer,
    context: ScriptContext,
  ) -> Bool {
    when redeemer is {
      Withdraw { owner_payment_pkh } -> {
        let must_be_signed =
          list.has(
            context.transaction.extra_signatories,
            datum.owner_payment_pkh,
          )
        owner_payment_pkh == datum.owner_payment_pkh && must_be_signed
      }
      Spend -> {
        // Must be signed by the bot
        let must_be_signed_by_bot =
          list.has(context.transaction.extra_signatories, datum.bot_payment_pkh)

        // Checking Timing is right
        let is_tx_time_valid =
          datum |> is_paymet_time_valid(context.transaction.validity_range)

        // Check right amount + fee is sent to destination address
        // Check new datum is created
        must_be_signed_by_bot && is_tx_time_valid
      }
    }
  }
}

test is_payment_time_valid_succeed() {
  let datum = Datum(#"", #"", None, 5, None, #"")
  is_payment_time_valid_v2(datum, after(6))
}
