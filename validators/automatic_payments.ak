use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/list
use aiken/time.{PosixTime}
use aiken/transaction.{
  InlineDatum, Input, Output, ScriptContext, Spend, Transaction, ValidityRange,
}
use aiken/transaction/credential.{Address, ScriptCredential, VerificationKey}
use aiken/transaction/value.{PolicyId, add}
use types/automatic_payments.{
  Daily, Datum, Days, ExecutePayment, Hourly, Hours, PaymentFrenquency, Redeemer,
  Settings, Weekly, Weeks, Withdraw, Yearly,
} as automatic_payments_types

// Sending funds must happen after a certain moment in time has passed, but also,
// if defined, a maximum delay has not passed.
// Example1: tx can be sent anytime after datum.start_time.
// Example2: tx can be sent anytime after datum.start_time, but before datum.max_payment_delay_hours
// have not passed after datum.start_time.
// In case of missing the payment slot, the bot is de facto stuck.
pub fn is_payment_time_valid(self: Datum, validity_range: ValidityRange) -> Bool {
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
            tx_latest_time < self.start_time + max_delay_hours * 60 * 60 * 1000

          _ -> False
        }
    }

  let is_payment_deadline_valid =
    when self.end_time is {
      Some(actual_end_time) ->
        interval.is_entirely_before(validity_range, actual_end_time)
      _ -> True
    }

  and {
    is_start_time_valid?,
    is_end_time_valid?,
    is_payment_deadline_valid?,
  }
}

fn hours_to_millis(hours: Int) {
  hours * 60 * 60 * 1_000
}

fn days_to_millis(days: Int) {
  days * hours_to_millis(24)
}

fn to_millis(payment_frenquency: PaymentFrenquency) -> Int {
  when payment_frenquency is {
    Hourly -> hours_to_millis(1)
    Hours { hours: _ } -> 10
    Daily -> days_to_millis(1)
    Days { days } -> days_to_millis(days)
    Weekly -> days_to_millis(7)
    Weeks { weeks } -> weeks * days_to_millis(7)
    Yearly -> days_to_millis(365)
  }
}

pub fn compute_new_start_time(
  start_time: PosixTime,
  payment_frequency: PaymentFrenquency,
  validity_range: ValidityRange,
) -> PosixTime {
  expect Finite(lower_bound) = validity_range.lower_bound.bound_type
  let k = ( lower_bound - start_time ) / to_millis(payment_frequency) + 1

  when payment_frequency is {
    Hourly -> start_time + k * hours_to_millis(1)
    Hours { hours } -> start_time + k * hours_to_millis(hours)
    Daily -> start_time + k * days_to_millis(1)
    Days { days } -> start_time + k * days_to_millis(days)
    Weekly -> start_time + k * days_to_millis(7)
    Weeks { weeks } -> start_time + k * weeks * days_to_millis(7)
    Yearly -> start_time + k * days_to_millis(365)
  }
}

pub fn load_settings(
  transaction: Transaction,
  settings_policy_id: PolicyId,
) -> Settings {
  expect Some(configuration_input) =
    transaction.reference_inputs
      |> list.find(
          fn(input) {
            input.output.value
              |> value.flatten()
              |> list.any(fn(asset) { asset.1st == settings_policy_id })
          },
        )
  expect InlineDatum(datum) = configuration_input.output.datum
  expect configuration: Settings = datum
  configuration
}

pub fn run_validation(
  locked_input: Output,
  payee_output: Output,
  returning_output: Output,
  validity_range: ValidityRange,
  extra_signatories: List<Hash<Blake2b_224, VerificationKey>>,
  settings: Settings,
) -> Bool {
  expect InlineDatum(data) = locked_input.datum
  expect datum: Datum = data

  // Build desired payee_address
  let payee_address =
    when datum.payee_stake_pkh is {
      Some(stake_pkh) ->
        datum.payee_payment_pkh
          |> credential.from_verification_key
          |> credential.with_delegation_key(stake_pkh)
      None -> credential.from_verification_key(datum.payee_payment_pkh)
    }
  // Ensure payee_output address matches desired one
  let is_payee_output_correct = payee_output.address == payee_address
  // Building amount to send to payee
  let value_to_send =
    list.foldl(
      datum.amount_to_send,
      value.zero(),
      fn(n, acc) { acc |> add(n.1st, n.2nd, n.3rd) },
    )
  // Check right amount is sent to payee
  let must_pay_payee = payee_output.value == value_to_send

  // Check right amount is returned to the script, if stake address is specified, the address must be a mingled or franken address.
  expect ScriptCredential(script_hash) = locked_input.address.payment_credential
  let script_address =
    when datum.owner_stake_pkh is {
      Some(stake_pkh) ->
        script_hash
          |> credential.from_script
          |> credential.with_delegation_key(stake_pkh)
      None -> credential.from_verification_key(script_hash)
    }
  // Ensure returning_output address matches desired one
  let is_returning_output_correct = returning_output.address == script_address

  // Checking Timing is right
  let is_tx_time_valid = datum |> is_payment_time_valid(validity_range)

  // check max fee
  let is_bot_fee_ok = datum.max_fees_lovelace >= settings.bot_fee_lovelace

  // Calculated the amount spent by the sender:
  // 1. bot operator fees
  // 2. transaction fee
  // 3. payment amount
  let spent_amount =
    value.from_lovelace(settings.bot_fee_lovelace)
      |> value.merge(value_to_send)
      |> value.negate

  let is_amount_sent_back_to_script_correct =
    returning_output.value == value.merge(locked_input.value, spent_amount)

  // Check new datum is correct, only new start time can be updated.
  // TODO: it should not matter, but what if start time is set to after end time?
  let expected_datum =
    Datum {
      ..datum,
      start_time: compute_new_start_time(
        datum.start_time,
        datum.payment_frenquency,
        validity_range,
      ),
    }
  expect InlineDatum(data) = returning_output.datum
  expect actual_datum: Datum = data
  let is_valid_datum = expected_datum == actual_datum

  // Must be signed by the bot
  let must_be_signed_by_bot =
    list.has(extra_signatories, settings.bot_payment_pkh)

  and {
    is_payee_output_correct?,
    must_pay_payee?,
    must_be_signed_by_bot?,
    is_returning_output_correct?,
    is_amount_sent_back_to_script_correct?,
    is_tx_time_valid?,
    is_bot_fee_ok?,
    is_valid_datum?,
  }
}

validator(settings_policy_id: PolicyId) {
  pub fn automatic_payments(
    data: Data,
    redeemer: Redeemer,
    context: ScriptContext,
  ) -> Bool {
    when redeemer is {
      Withdraw -> {
        expect datum: Datum = data
        let must_be_signed_by_owner =
          list.has(
            context.transaction.extra_signatories,
            datum.owner_payment_pkh,
          )
        must_be_signed_by_owner
      }
      ExecutePayment { in_index, num_batch_payments } -> {
        expect ScriptContext { transaction: tx, purpose: Spend(own_ref) } =
          context

        let Transaction { inputs, outputs, .. } = tx

        // Filtering non-scripts inputs out, so to get rid of supporting
        // wallet utxos used to cover for tx and collect protocol fees in case of 
        // minutxo < ~1ada
        // This way we can use just 1 index for input that will be used to calculated
        // matching outputs. 
        // Payee outputs will have same index. Returning outputs will have index + num_payments
        // admin wallet change address will always be last.
        expect Some(Input { output: in_utxo, output_reference: in_ref }) =
          inputs
            |> list.filter(
                fn(input) {
                  when input.output.address.payment_credential is {
                    ScriptCredential(_) -> True
                    _ -> False
                  }
                },
              )
            |> list.at(in_index)

        // Input to Outputs pairing + Double Satisfaction Prevention
        // Instead of pairing inputs and outputs (where manually setting outputs indexes could lead to double satisfaction)
        // Here only inputs indexes are set, matched against the spend output ref, and outputs are expected to be in a determined position
        let returning_out_index = in_index + num_batch_payments
        expect Some(out_utxo) = outputs |> list.at(in_index)
        expect Some(returning_output) = outputs |> list.at(returning_out_index)

        // Indicated input must match the spending one.
        expect (own_ref == in_ref)?

        // Read configuration from ref input
        let settings = load_settings(tx, settings_policy_id)
        run_validation(
          in_utxo,
          out_utxo,
          returning_output,
          tx.validity_range,
          tx.extra_signatories,
          settings,
        )
      }
    }
  }
}
