use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, PaymentCredential, Script}
use cardano/assets.{Value, merge, zero}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, ValidityRange,
}
use types/automatic_payments.{
  Configuration, Daily, Datum, Days, ExecutePayment, Hourly, Hours,
  PaymentFrenquency, Redeemer, Weekly, Weeks, Withdraw, Yearly,
} as automatic_payments_types

// This will be replace with the policy ID of an NFT at a later stage
pub const configuration_nft =
  #"00000000000000000000000000000000000000000000000000000000"

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
        !interval.contains(validity_range, actual_end_time)
      _ -> True
    }

  is_start_time_valid? && is_end_time_valid? && is_payment_deadline_valid?
}

// Right amonut is sent to payee
pub fn is_right_amount_sent_to_payee(
  payee_address: Address,
  outputs: List<Output>,
  value_to_send: Value,
) -> Bool {
  let payee_outputs = list.filter(outputs, fn(o) { o.address == payee_address })
  // Caluculate total value sent to payee
  let value_sent_to_payee =
    list.foldl(payee_outputs, zero, fn(n, acc) { merge(n.value, acc) })
  value_sent_to_payee == value_to_send
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
  start_time: Int,
  payment_frequency: PaymentFrenquency,
  validity_range: ValidityRange,
) -> Int {
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

pub fn load_configuration(transaction: Transaction) -> Configuration {
  expect Some(configuration_input) =
    transaction.reference_inputs
      |> list.find(
          fn(input) {
            input.output.value
              |> assets.flatten()
              |> list.any(fn(asset) { asset.1st == configuration_nft })
          },
        )
  expect InlineDatum(datum) = configuration_input.output.datum
  expect configuration: Configuration = datum
  configuration
}

validator automatic_payments {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    when redeemer is {
      Withdraw -> {
        trace @"Withdraw"
        expect Some(data) = datum
        let must_be_signed_by_owner =
          list.has(self.extra_signatories, data.owner_payment_pkh)
        must_be_signed_by_owner
      }
      ExecutePayment -> {
        trace @"ExecutePayment"

        expect Some(data) = datum
        // ScriptContext { transaction: Transaction, redeemer: Redeemer, info: ScriptInfo }
        // Find the input locked by the script
        let locked_input_opt =
          list.find(self.inputs, fn(x) { x.output_reference == own_ref })
        expect Some(locked_input) = locked_input_opt
        let Transaction { outputs, .. } = self

        // Value is an opaque type, so build it here from the list of tokens in the datum.
        let value_to_send =
          list.foldl(
            data.amount_to_send,
            zero,
            fn(n, acc) { acc |> assets.add(n.1st, n.2nd, n.3rd) },
          )

        // Read configuration from ref input
        let configuration = load_configuration(self)

        // Checking Timing is right
        let is_tx_time_valid =
          data |> is_payment_time_valid(self.validity_range)

        // Check right amount is sent to payee
        let payee_address =
          when data.payee_stake_pkh is {
            Some(stake_pkh) ->
              data.payee_payment_pkh
                |> address.from_verification_key
                |> address.with_delegation_key(stake_pkh)
            None -> address.from_verification_key(data.payee_payment_pkh)
          }
        let must_pay_payee =
          is_right_amount_sent_to_payee(payee_address, outputs, value_to_send)

        // Check right amount is returned to the script, if stake address is specified, the address must be a mingled or franken address.
        expect Script(script_hash) =
          locked_input.output.address.payment_credential

        let script_address =
          when data.owner_stake_pkh is {
            Some(stake_pkh) ->
              script_hash
                |> address.from_verification_key
                |> address.with_delegation_key(stake_pkh)
            None -> address.from_verification_key(script_hash)
          }

        expect [script_output] =
          list.filter(outputs, fn(o) { o.address == script_address })

        // check max fee
        let is_bot_fee_ok =
          data.max_fees_lovelace >= configuration.bot_fee_lovelace

        // Calculated the amount spent by the sender:
        // 1. bot operator fees
        // 2. transaction fee
        // 3. payment amount
        let spent_amount =
          assets.from_lovelace(configuration.bot_fee_lovelace)
            |> assets.merge(value_to_send)
            |> assets.merge(assets.from_lovelace(self.fee))
            |> assets.negate
        let is_amount_sent_back_to_script_correct =
          script_output.value == assets.merge(
            locked_input.output.value,
            spent_amount,
          )

        // Check new datum is created
        let expected_datum =
          Datum {
            ..data,
            start_time: compute_new_start_time(
              data.start_time,
              data.payment_frenquency,
              self.validity_range,
            ),
          }
        expect InlineDatum(data) = script_output.datum
        expect actual_datum: Datum = data
        let is_valid_datum = expected_datum == actual_datum

        // Must be signed by the bot
        let must_be_signed_by_bot =
          list.has(self.extra_signatories, configuration.bot_payment_pkh)

        must_pay_payee? && must_be_signed_by_bot? && is_amount_sent_back_to_script_correct? && is_valid_datum? && is_tx_time_valid? && is_bot_fee_ok?
      }
    }
  }

  else(_) {
    fail
  }
}
