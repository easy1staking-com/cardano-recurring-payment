use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{PolicyId, Value, add}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, ValidityRange,
}
use types/automatic_payments.{
  AssetAmount, AutomatedPayment, ExecutePayment, Redeemer, Settings, Withdraw,
} as automatic_payments_types

// Sending funds must happen after a certain moment in time has passed, but also,
// if defined, a maximum delay has not passed.
// Example1: tx can be sent anytime after datum.start_time.
// Example2: tx can be sent anytime after datum.start_time, but before datum.max_payment_delay_hours
// have not passed after datum.start_time.
// In case of missing the payment slot, the bot is de facto stuck.
pub fn is_payment_time_valid(
  self: AutomatedPayment,
  validity_range: ValidityRange,
) -> Bool {
  expect Finite(tx_earliest_time) = validity_range.lower_bound.bound_type
  let is_start_time_valid = self.start_time <= tx_earliest_time

  let is_end_time_valid =
    when self.max_payment_delay_hours is {
      None -> True
      Some(max_delay_hours) -> {
        expect Finite(tx_latest_time) = validity_range.upper_bound.bound_type
        tx_latest_time <= self.start_time + to_millis(max_delay_hours)
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

fn to_millis(hours: Int) {
  // hours * 60 * 60 * 1_000
  hours * 3_600_000
}

pub fn compute_new_start_time(
  start_time: Int,
  payment_interval_hours: Int,
  validity_range: ValidityRange,
) -> Int {
  expect Finite(lower_bound) = validity_range.lower_bound.bound_type
  let k = ( lower_bound - start_time ) / to_millis(payment_interval_hours) + 1

  start_time + k * to_millis(payment_interval_hours)
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
              |> assets.flatten()
              |> list.any(fn(asset) { asset.1st == settings_policy_id })
          },
        )
  expect InlineDatum(datum) = configuration_input.output.datum
  expect settings: Settings = datum
  settings
}

pub fn calculate_spent_amount(
  fee_exempt_user_index: Option<Int>,
  settings: Settings,
  datum: AutomatedPayment,
  value_to_send: Value,
) -> Value {
  // Calculated the amount spent by the sender:
  // 1. bot operator fees (wich may be forfaited for specific users)
  // 2. base fee
  // 3. payment amount
  // FIXME: Theoretically, if someone sets up a payment w/ pkh of a fee exempt user, they might
  // take advantage of free payments, but they won't be able to withdraw the funds and actually give control
  // to someone else.
  let operator_fee_lovelaces =
    when fee_exempt_user_index is {
      Some(user_index) -> {
        expect Some(user_pk) =
          list.at(settings.operator_fee_exempt_users, user_index)
        let actual_hash =
          when datum.owner.payment_credential is {
            VerificationKey(payment_credential_hash) -> payment_credential_hash
            Script(script_hash) -> script_hash
          }
        expect user_pk == actual_hash
        assets.zero
      }
      _ -> assets.from_lovelace(settings.operator_fee_lovelace)
    }
  // Maximum spent amount.
  let spent_amount =
    assets.from_lovelace(settings.base_fee_lovelace)
      |> assets.merge(operator_fee_lovelaces)
      |> assets.merge(value_to_send)
      |> assets.negate
  spent_amount
}

pub fn is_returning_output_correct(
  locked_input: Output,
  returning_output_opt: Option<Output>,
  datum: AutomatedPayment,
  spent_amount: Value,
  validity_range: ValidityRange,
) -> Bool {
  // Must check that, if expected, there's a payment back into the contract
  // In case of non-recurring payments, we don't care
  // In case or recurring payments, the right amount must be paid back to the contract,
  // with the exception of the last payment where there's not enough for min_utxo.
  when datum.payment_interval_hours is {
    Some(payment_interval_hours) -> {
      // Expected minimum amount (token + ada) that must be returned.
      let expected_returning_amount =
        assets.merge(locked_input.value, spent_amount)
      // Split value in tokens and lovelaces
      // Returned tokens must match exactly between expected and actual
      let token_expected_returning_amount =
        assets.without_lovelace(expected_returning_amount)
      let ada_expected_returning_amount =
        assets.lovelace_of(expected_returning_amount)
      // If there are no tokens left and less than 1 ada, we don't check for returning output.
      let no_tokens = assets.is_zero(token_expected_returning_amount)
      let less_than_min_utxo = ada_expected_returning_amount < 1_000_000
      if no_tokens && less_than_min_utxo {
        True
      } else {
        expect Some(returning_output) = returning_output_opt
        is_returning_amount_correct(
          locked_input,
          returning_output,
          datum,
          ada_expected_returning_amount,
          token_expected_returning_amount,
          payment_interval_hours,
          validity_range,
        )
      }
    }
    _ -> True
  }
}

// check we're paying the right amount to the right adreess
pub fn is_returning_amount_correct(
  locked_input: Output,
  returning_output: Output,
  datum: AutomatedPayment,
  ada_expected_returning_amount: Int,
  token_expected_returning_amount: Value,
  payment_interval_hours: Int,
  validity_range: ValidityRange,
) -> Bool {
  // Check right amount is returned to the script, if stake address is specified, the address must be a mingled or franken address.
  expect Script(script_hash) = locked_input.address.payment_credential
  let script_address =
    when datum.owner.stake_credential is {
      Some(Inline(stake_credential)) ->
        when stake_credential is {
          VerificationKey(key_hash) ->
            address.from_script(script_hash)
              |> address.with_delegation_key(key_hash)
          Script(script_hash) ->
            address.from_script(script_hash)
              |> address.with_delegation_script(script_hash)
        }

      _ -> address.from_script(script_hash)
    }

  // Ensure returning_output address matches desired one
  let is_returning_address_correct = returning_output.address == script_address

  // Ensure at least a certain amount of ada is returned
  let ada_returning_amount = assets.lovelace_of(returning_output.value)
  let is_ada_returning_amount_correct =
    ada_returning_amount >= ada_expected_returning_amount

  // Ensure the exact amount of token is returned. If any.
  let token_returning_amount = assets.without_lovelace(returning_output.value)
  let is_token_returning_amount_correct =
    token_expected_returning_amount == token_returning_amount

  // Ada amount must be greater equal (because of possible base fee split)
  // Check new datum is correct, only new start time can be updated.
  // TODO: it should not matter, but what if start time is set to after end time?
  let expected_datum =
    AutomatedPayment {
      ..datum,
      start_time: compute_new_start_time(
        datum.start_time,
        payment_interval_hours,
        validity_range,
      ),
    }
  expect InlineDatum(data) = returning_output.datum
  expect actual_datum: AutomatedPayment = data

  let is_output_datum_correct = expected_datum == actual_datum

  and {
    is_returning_address_correct?,
    is_output_datum_correct?,
    is_ada_returning_amount_correct?,
    is_token_returning_amount_correct?,
  }
}

pub fn compute_value_to_send(amount_to_send: List<AssetAmount>) -> Value {
  list.foldl(
    amount_to_send,
    assets.zero,
    fn(n, acc) { acc |> add(n.policy_id, n.asset_name, n.amount) },
  )
}

// Check the desired amount is sent to the right address
pub fn is_payment_correct(
  value_to_send: Value,
  payee_output: Output,
  datum: AutomatedPayment,
) -> Bool {
  and {
    // Ensure payee_output address matches desired one
    payee_output.address == datum.payee,
    // Check right amount is sent to payee
    payee_output.value == value_to_send,
  }
}

pub fn enough_funds_locked(locked_input: Output, spent_amount: Value) -> Bool {
  assets.negate(spent_amount)
    |> assets.merge(locked_input.value)
    |> assets.reduce(
        True,
        fn(_policyId, _assetName, amount, result) { amount >= 0 && result },
      )
}

pub fn run_validation(
  datum: AutomatedPayment,
  locked_input: Output,
  payee_output: Output,
  returning_output_opt: Option<Output>,
  validity_range: ValidityRange,
  settings: Settings,
  fee_exempt_user_index: Option<Int>,
) -> Bool {
  // Building amount to send to payee
  let value_to_send = compute_value_to_send(datum.amount_to_send)

  let spent_amount =
    calculate_spent_amount(
      fee_exempt_user_index,
      settings,
      datum,
      value_to_send,
    )

  let is_enough_funds_locked = enough_funds_locked(locked_input, spent_amount)

  // Check if actual payment is executed
  let is_payment_correct =
    is_payment_correct(value_to_send, payee_output, datum)

  let is_returning_output_correct =
    is_returning_output_correct(
      locked_input,
      returning_output_opt,
      datum,
      spent_amount,
      validity_range,
    )

  // Checking Timing is right
  let is_tx_time_valid = datum |> is_payment_time_valid(validity_range)

  // check max fee
  let is_bot_fee_ok =
    datum.max_fees_lovelace >= settings.operator_fee_lovelace + settings.base_fee_lovelace

  and {
    is_enough_funds_locked?,
    is_payment_correct?,
    is_returning_output_correct?,
    is_tx_time_valid?,
    is_bot_fee_ok?,
  }
}

// The goal of this validator is to allow
// 1. a certain value
// 2. to be sent to a specific address
// 3. after a certain instant
// 4. optionally within a certain delay
// 5. return remaining funds (minus fees) to same script address + desired optional stake address
// 6. prepare for next timed payment (if supposed to - end_time)
validator automatic_payments(settings_policy_id: PolicyId) {
  spend(
    datum: Option<AutomatedPayment>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    when redeemer is {
      // Owner can spend anytime. 
      Withdraw -> {
        expect Some(actual_datum) = datum
        let crendetials_hash =
          when actual_datum.owner.payment_credential is {
            VerificationKey(key_hash) -> key_hash
            Script(script_hash) -> script_hash
          }
        let must_be_signed_by_owner =
          list.has(tx.extra_signatories, crendetials_hash)
        must_be_signed_by_owner
      }
      ExecutePayment {
        in_index,
        num_batch_payments,
        operator_index,
        fee_exempt_user_index,
      } -> {
        let Transaction { inputs, outputs, .. } = tx

        expect Some(input) =
          inputs
            |> transaction.find_input(own_ref)
        expect Script(ownScriptHash) = input.output.address.payment_credential

        // Filtering non-scripts inputs out, so to get rid of supporting
        // wallet utxos used to cover for tx and collect protocol fees in case of 
        // minutxo < ~1ada
        // This way we can use just 1 index for input that will be used to calculated
        // matching outputs. 
        // Payee outputs will have same index. Returning outputs will have index + num_payments
        // admin wallet change address will always be last.
        // NOTE: tx w/o returning output can only be batched together as we can't mix tx w/ returning
        // and not returning output as it will break validation
        expect Some(Input { output: in_utxo, output_reference: in_ref }) =
          inputs
            |> list.filter(
                fn(input) {
                  when input.output.address.payment_credential is {
                    Script(hash) -> hash == ownScriptHash
                    _ -> False
                  }
                },
              )
            |> list.at(in_index)

        // Input to Outputs pairing + Double Satisfaction Prevention
        // Instead of pairing inputs and outputs (where manually setting outputs indexes could lead to double satisfaction)
        // Here only inputs indexes are set, matched against the spend output ref, and outputs are expected to be in a determined position
        expect Some(out_utxo) = outputs |> list.at(in_index)

        let returning_out_index = in_index + num_batch_payments
        // This can be None..., but if it must be some, will fail later.
        let returning_output_opt = outputs |> list.at(returning_out_index)

        // Indicated input must match the spending one.
        expect (own_ref == in_ref)?

        // Read configuration from ref input
        let settings = load_settings(tx, settings_policy_id)
        // Must be signed by the bot
        // Use index to fetch operator key
        expect Some(operator_pkh) =
          list.at(settings.authorised_operators, operator_index)
        // Ensure key has signed the tx
        expect list.has(tx.extra_signatories, operator_pkh)?
        expect Some(actual_datum) = datum
        run_validation(
          actual_datum,
          in_utxo,
          out_utxo,
          returning_output_opt,
          tx.validity_range,
          settings,
          fee_exempt_user_index,
        )
      }
    }
  }

  else(_) {
    fail
  }
}
