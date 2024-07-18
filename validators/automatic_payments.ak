use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/list
use aiken/time.{PosixTime}
use aiken/transaction.{
  InlineDatum, Output, ScriptContext, Spend, Transaction, ValidityRange,
}
use aiken/transaction/credential.{
  Address, ScriptCredential, VerificationKeyCredential,
}
use aiken/transaction/value.{Value, add}
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
  is_start_time_valid? && is_end_time_valid?
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
    list.foldl(
      payee_outputs,
      value.zero(),
      fn(n, acc) { value.merge(n.value, acc) },
    )
  value_sent_to_payee == value_to_send
}

fn hours_to_millis(hours: Int) {
  hours * 60 * 60 * 1_000
}

fn days_to_millis(days: Int) {
  days * hours_to_millis(24)
}

pub fn compute_new_start_time(
  start_time: PosixTime,
  payment_frenquency: PaymentFrenquency,
) -> PosixTime {
  when payment_frenquency is {
    Hourly -> start_time + hours_to_millis(1)
    Hours { hours } -> start_time + hours_to_millis(hours)
    Daily -> start_time + days_to_millis(1)
    Days { days } -> start_time + days_to_millis(days)
    Weekly -> start_time + days_to_millis(7)
    Weeks { weeks } -> start_time + weeks * days_to_millis(7)
    Yearly -> start_time + days_to_millis(365)
  }
}

pub fn load_configuration(transaction: Transaction) -> Configuration {
  expect Some(configuration_input) =
    transaction.reference_inputs
      |> list.find(
          fn(input) {
            input.output.value
              |> value.flatten()
              |> list.any(fn(asset) { asset.1st == configuration_nft })
          },
        )
  expect InlineDatum(datum) = configuration_input.output.datum
  expect configuration: Configuration = datum
  configuration
}

validator {
  pub fn automatic_payments(
    datum: Datum,
    redeemer: Redeemer,
    context: ScriptContext,
  ) -> Bool {
    when redeemer is {
      Withdraw -> {
        trace @"Withdraw"
        let must_be_signed_by_owner =
          list.has(
            context.transaction.extra_signatories,
            datum.owner_payment_pkh,
          )
        must_be_signed_by_owner
      }
      ExecutePayment -> {
        trace @"ExecutePayment"

        // Common part
        let ScriptContext { transaction, purpose } = context
        expect Spend(locked_input_reference) = purpose

        // Find the input locked by the script
        let locked_input_opt =
          list.find(
            transaction.inputs,
            fn(x) { locked_input_reference == x.output_reference },
          )
        expect Some(locked_input) = locked_input_opt
        let Transaction { outputs, .. } = transaction

        // Value is an opaque type, so build it here from the list of tokens in the datum.
        let value_to_send =
          list.foldl(
            datum.amount_to_send,
            value.zero(),
            fn(n, acc) { acc |> add(n.1st, n.2nd, n.3rd) },
          )

        // Read configuration from ref input
        let configuration = load_configuration(transaction)

        // Checking Timing is right
        let is_tx_time_valid =
          datum |> is_payment_time_valid(context.transaction.validity_range)

        // Check right amount is sent to payee
        let payee_address =
          Address {
            payment_credential: datum.payee_payment_credential,
            stake_credential: datum.payee_stake_credential,
          }
        let must_pay_payee =
          is_right_amount_sent_to_payee(payee_address, outputs, value_to_send)

        // Check right amount is returned to the script, if stake address is specified, the address must be a mingled or franken address.
        expect ScriptCredential(script_hash) =
          locked_input.output.address.payment_credential
        let script_address =
          Address {
            payment_credential: VerificationKeyCredential(script_hash),
            stake_credential: datum.owner_stake_pkh,
          }
        expect [script_output] =
          list.filter(outputs, fn(o) { o.address == script_address })

        // Calculated the amount spent by the sender:
        // 1. bot operator fees
        // 2. transaction fee
        // 3. payment amount
        let spent_amount =
          value.from_lovelace(configuration.bot_fee_lovelaces)
            |> value.merge(value_to_send)
            |> value.merge(transaction.fee)
            |> value.negate
        let is_amount_sent_back_to_script_correct =
          script_output.value == value.merge(
            locked_input.output.value,
            spent_amount,
          )

        // Check new datum is created
        let expected_datum =
          Datum {
            ..datum,
            start_time: compute_new_start_time(
              datum.start_time,
              datum.payment_frenquency,
            ),
          }
        expect InlineDatum(data) = script_output.datum
        expect actual_datum: Datum = data
        let is_valid_datum = expected_datum == actual_datum

        // Must be signed by the bot
        let must_be_signed_by_bot =
          list.has(
            context.transaction.extra_signatories,
            configuration.bot_payment_pkh,
          )

        must_pay_payee? && must_be_signed_by_bot? && is_amount_sent_back_to_script_correct? && is_valid_datum? && is_tx_time_valid?
      }
    }
  }
}
