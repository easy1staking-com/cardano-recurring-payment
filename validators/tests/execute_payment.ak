use aiken/cbor
use aiken/interval.{after, between}
use automatic_payments.{
  compute_new_start_time, compute_value_to_send, enough_funds_locked,
  is_payment_correct, is_payment_time_valid, is_returning_amount_correct,
  load_settings,
}
use cardano/address
use cardano/assets.{add}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use tests/fixtures.{datum_template}
use types/automatic_payments.{
  AssetAmount, AutomatedPayment, ExecutePayment, RescueFunds, Settings, Withdraw,
} as automatic_payments_types

const payment_pkh = #"4f0f62955aaac98d8ffc1d26279cfafc9cbf46f44225e269bbe29560"

const staking_pkh = #"420268df8f2f20358ff8305836ed590ab691b7263e28ea5d60b4ac51"

const payment_pkh_1 =
  #"869423edf942154f9a965a51a06639a2645f23a67fe849ecbe8762b4"

// const payee_staking_pkh =
//   #"414c2c4e10f6171c57b4fbc6f2fdb10139cd43058092732fcdb3a764"

const bot_payment_pkh =
  #"018f6b977da177061ad00cf4ef14f429ebc7befb40a843314e7575d9"

const settings_policy_id =
  #"581ccfaf54b77c8bbd8e3ce9a0afcbcc51f02f484c583760f70bf873a21d"

test automatic_payments_succeed_withdraw() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1719835200000,
    }
  let output_reference = OutputReference("", 0)
  let transaction =
    Transaction { ..placeholder, extra_signatories: [payment_pkh] }
  automatic_payments.automatic_payments.spend(
    #"",
    Some(datum),
    Withdraw,
    output_reference,
    transaction,
  )
}

test automatic_payments_fail_withdraw() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1719835200000,
    }
  let output_reference = OutputReference("", 0)
  let transaction =
    Transaction { ..placeholder, extra_signatories: [payment_pkh_1] }
  !automatic_payments.automatic_payments.spend(
    #"",
    Some(datum),
    Withdraw,
    output_reference,
    transaction,
  )
}

test is_returning_amount_correct_succeed() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1721163789000,
    }

  let address =
    address.from_script(payment_pkh)
      |> address.with_delegation_key(staking_pkh)
  let locked_input =
    Output {
      address,
      value: assets.zero,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let returning_datum = AutomatedPayment { ..datum, start_time: 1721167389000 }

  let returning_output =
    Output {
      ..locked_input,
      address: address,
      value: assets.from_lovelace(5_000_000),
      datum: InlineDatum(returning_datum),
    }

  is_returning_amount_correct(
    Input(OutputReference(#"", 0), locked_input),
    returning_output: returning_output,
    datum: datum,
    ada_expected_returning_amount: 5_000_000,
    token_expected_returning_amount: assets.zero,
    payment_interval_hours: 1,
    validity_range: between(1721164509000, 1721165409000),
  )
}

test is_returning_amount_correct_succeed_with_token() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1721163789000,
    }

  let address =
    address.from_script(payment_pkh)
      |> address.with_delegation_key(staking_pkh)
  let locked_input =
    Output {
      address,
      value: assets.zero,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let returning_datum = AutomatedPayment { ..datum, start_time: 1721167389000 }

  let returning_output =
    Output {
      ..locked_input,
      address: address,
      value: assets.from_lovelace(5_000_000)
        |> add(#"abba", #"abba", 10_000_000),
      datum: InlineDatum(returning_datum),
    }

  is_returning_amount_correct(
    Input(OutputReference(#"", 0), locked_input),
    returning_output: returning_output,
    datum: datum,
    ada_expected_returning_amount: 5_000_000,
    token_expected_returning_amount: assets.from_asset(
      #"abba",
      #"abba",
      10_000_000,
    ),
    payment_interval_hours: 1,
    validity_range: between(1721164509000, 1721165409000),
  )
}

test is_returning_amount_correct_fail_address() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1721163789000,
    }

  let address =
    address.from_script(payment_pkh)
      |> address.with_delegation_key(staking_pkh)
  let locked_input =
    Output {
      address,
      value: assets.zero,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let returning_datum = AutomatedPayment { ..datum, start_time: 1721167389000 }

  let returning_output =
    Output {
      ..locked_input,
      address: address.from_script(payment_pkh_1)
        |> address.with_delegation_key(staking_pkh),
      value: assets.from_lovelace(5_000_000)
        |> add(#"abba", #"abba", 10_000_000),
      datum: InlineDatum(returning_datum),
    }

  !is_returning_amount_correct(
    Input(OutputReference(#"", 0), locked_input),
    returning_output: returning_output,
    datum: datum,
    ada_expected_returning_amount: 5_000_000,
    token_expected_returning_amount: assets.from_asset(
      #"abba",
      #"abba",
      10_000_000,
    ),
    payment_interval_hours: 1,
    validity_range: between(1721164509000, 1721165409000),
  )
}

test is_returning_amount_correct_fail_start_time() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1721163789000,
    }

  let address =
    address.from_script(payment_pkh)
      |> address.with_delegation_key(staking_pkh)
  let locked_input =
    Output {
      address,
      value: assets.zero,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let returning_datum = AutomatedPayment { ..datum, start_time: 1721167380000 }

  let returning_output =
    Output {
      ..locked_input,
      address: address,
      value: assets.from_lovelace(5_000_000)
        |> add(#"abba", #"abba", 10_000_000),
      datum: InlineDatum(returning_datum),
    }

  !is_returning_amount_correct(
    Input(OutputReference(#"", 0), locked_input),
    returning_output: returning_output,
    datum: datum,
    ada_expected_returning_amount: 5_000_000,
    token_expected_returning_amount: assets.from_asset(
      #"abba",
      #"abba",
      10_000_000,
    ),
    payment_interval_hours: 1,
    validity_range: between(1721164509000, 1721165409000),
  )
}

test compute_value_to_send_zero() {
  let value_to_send = compute_value_to_send([])

  assets.is_zero(value_to_send)
}

test compute_value_to_send_simple_1_ada() {
  let value_to_send = compute_value_to_send([AssetAmount(#"", #"", 1_000_000)])

  value_to_send == assets.from_lovelace(1_000_000)
}

test compute_value_to_send_simple_2_times_1_ada() {
  let value_to_send =
    compute_value_to_send(
      [AssetAmount(#"", #"", 1_000_000), AssetAmount(#"", #"", 1_000_000)],
    )

  value_to_send == assets.from_lovelace(2_000_000)
}

test compute_value_to_send_token_ada() {
  let actual_value_to_send =
    compute_value_to_send(
      [
        AssetAmount(#"", #"", 1_000_000),
        AssetAmount(#"", #"", 1_000_000),
        AssetAmount(#"abba", #"abba", 5_000_000),
      ],
    )

  let expected_value_to_send =
    assets.from_lovelace(2_000_000) |> assets.add(#"abba", #"abba", 5_000_000)

  actual_value_to_send == expected_value_to_send
}

test compute_value_to_send_token_ada_fail() {
  let actual_value_to_send =
    compute_value_to_send(
      [
        AssetAmount(#"", #"", 1_000_000),
        AssetAmount(#"", #"", 1_000_000),
        AssetAmount(#"abba", #"abba", 15_000_000),
      ],
    )

  let expected_value_to_send =
    assets.from_lovelace(2_000_000) |> assets.add(#"abba", #"abba", 5_000_000)

  actual_value_to_send != expected_value_to_send
}

test is_payment_correct_succeed() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      payee: address.from_verification_key(payment_pkh)
        |> address.with_delegation_key(staking_pkh),
    }
  is_payment_correct(
    value_to_send: assets.from_lovelace(5_000_000),
    payee_output: Output {
      address: address.from_verification_key(payment_pkh)
        |> address.with_delegation_key(staking_pkh),
      value: assets.from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
    datum: datum,
  )
}

test is_payment_correct_fails_amount() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      payee: address.from_verification_key(payment_pkh)
        |> address.with_delegation_key(staking_pkh),
    }
  !is_payment_correct(
    value_to_send: assets.from_lovelace(15_000_000),
    payee_output: Output {
      address: address.from_verification_key(payment_pkh)
        |> address.with_delegation_key(staking_pkh),
      value: assets.from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
    datum: datum,
  )
}

test is_payment_correct_fails_staking_address() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      payee: address.from_verification_key(payment_pkh)
        |> address.with_delegation_key(staking_pkh),
    }
  !is_payment_correct(
    value_to_send: assets.from_lovelace(5_000_000),
    payee_output: Output {
      address: address.from_verification_key(payment_pkh),
      value: assets.from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
    datum: datum,
  )
}

test is_payment_correct_fails_payment_address() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      payee: address.from_verification_key(payment_pkh)
        |> address.with_delegation_key(staking_pkh),
    }
  !is_payment_correct(
    value_to_send: assets.from_lovelace(5_000_000),
    payee_output: Output {
      address: address.from_verification_key(payment_pkh_1)
        |> address.with_delegation_key(staking_pkh),
      value: assets.from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
    datum: datum,
  )
}

// Validity time/interval tests
test is_payment_time_valid_succeed_start_time_only() {
  let datum = AutomatedPayment { ..datum_template(), start_time: 1719835200000 }
  is_payment_time_valid(datum, after(1719838800000))
}

test is_payment_time_valid_succeed_start_time_only_interval() {
  let datum = AutomatedPayment { ..datum_template(), start_time: 1719835200000 }
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_and_max_delay() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_overlap_and_max_delay() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  is_payment_time_valid(datum, between(1719835200000, 1719849600000))
}

test is_payment_time_valid_fail_start_time_and_max_delay_overlap() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  !is_payment_time_valid(datum, between(1719831600000, 1719853200000))
}

test is_payment_time_valid_fail_earlier_start_time_must_fail() fail {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  !is_payment_time_valid(datum, after(1719831600000))
}

// Add Valid interval test, no max hours and end_time and everything still works
test is_payment_time_valid_succeed_start_time_and_time() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      end_time: Some(1720699200000),
    }
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
  // this might have to become between.
}

// Add Valid interval test, with max hours and end_time and everything still works
test is_payment_time_valid_succeed_start_time_and_time_max_hours() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
      end_time: Some(1720699200000),
    }
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

// Add Fail interval test, with max hours and end_time and it fails because of max hours
test is_payment_time_valid_fail_start_time_and_time_and_fail_max_hours() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
      end_time: Some(1720699200000),
    }
  !is_payment_time_valid(datum, between(1719831600000, 1719853200000))
}

// Add Fail interval test, it will initially pass, but then after code it should fail
test is_payment_time_valid_fail_start_time_and_end_time_and_fail_end_time() {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
      end_time: Some(1719842400000),
    }
  !is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

// New Start time tests
test compute_new_start_time_1_hour() {
  compute_new_start_time(
    1721163789000,
    1,
    between(1721164509000, 1721165409000),
  ) == 1721167389000
}

test compute_new_start_time_1_day() {
  compute_new_start_time(
    1721163789000,
    24,
    between(1721164509000, 1721165409000),
  ) == 1721250189000
}

test compute_new_start_time_3_day() {
  compute_new_start_time(
    1721163789000,
    3 * 24,
    between(1721164509000, 1721165409000),
  ) == 1721422989000
}

test compute_new_start_time_5_day() {
  compute_new_start_time(
    1721163789000,
    5 * 24,
    between(1721164509000, 1721165409000),
  ) == 1721595789000
}

test compute_new_start_time_2_weeks() {
  compute_new_start_time(
    1721163789000,
    2 * 7 * 24,
    between(1721164509000, 1721165409000),
  ) == 1722373389000
}

test compute_new_start_time_end_time_skip_1h() {
  compute_new_start_time(
    1721163789000,
    1,
    between(1721167809000, 1721169009000),
  ) == 1721170989000
}

// Testing Settings
test load_configuration_fail_no_ref_inputs() fail {
  let transaction: Transaction = placeholder
  let configuration =
    load_settings(
      transaction,
      #"00000000000000000000000000000000000000000000000000000000",
    )
  configuration == configuration
}

test load_configuration_fail_missing_configuration_ref_input() fail {
  let address = payment_pkh_1 |> address.from_verification_key

  let transaction =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input(
          OutputReference(#"", 0),
          Output {
            address,
            value: assets.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
      ],
    }

  let configuration =
    load_settings(
      transaction,
      #"00000000000000000000000000000000000000000000000000000000",
    )
  configuration == configuration
}

test load_configuration_fail_no_datum() fail {
  let address = payment_pkh_1 |> address.from_verification_key

  let transaction =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input(
          OutputReference(#"", 0),
          Output {
            address,
            value: assets.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
        Input(
          OutputReference(#"", 0),
          Output {
            address,
            value: assets.from_lovelace(10_000_000)
              |> add(
                  #"00000000000000000000000000000000000000000000000000000000",
                  "settings",
                  1,
                ),
            datum: NoDatum,
            reference_script: None,
          },
        ),
      ],
    }

  let configuration =
    load_settings(
      transaction,
      #"00000000000000000000000000000000000000000000000000000000",
    )
  configuration == configuration
}

test load_configuration_succeed() {
  let address = payment_pkh_1 |> address.from_verification_key
  let expected_configuration =
    Settings(bot_payment_pkh, [bot_payment_pkh], [], 1_000_000, 360_000)
  let transaction =
    Transaction {
      ..placeholder,
      reference_inputs: [
        Input(
          OutputReference(#"", 0),
          Output {
            address,
            value: assets.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
        Input(
          OutputReference(#"", 0),
          Output {
            address,
            value: assets.from_lovelace(10_000_000)
              |> add(
                  #"00000000000000000000000000000000000000000000000000000000",
                  "settings",
                  1,
                ),
            datum: InlineDatum(expected_configuration),
            reference_script: None,
          },
        ),
      ],
    }

  let actual_configuration =
    load_settings(
      transaction,
      #"00000000000000000000000000000000000000000000000000000000",
    )
  actual_configuration == expected_configuration
}

// Enough funds locked
test enough_funds_locked_suceed_gt() {
  enough_funds_locked(
    Output(
      address.from_verification_key(#""),
      assets.from_lovelace(2_000_000),
      NoDatum,
      None,
    ),
    assets.from_lovelace(1_000_000),
  )
}

test enough_funds_locked_suceed_eq() {
  enough_funds_locked(
    Output(
      address.from_verification_key(#""),
      assets.from_lovelace(1_000_000),
      NoDatum,
      None,
    ),
    assets.from_lovelace(1_000_000),
  )
}

test enough_funds_locked_fails_not_enough_ada() {
  !enough_funds_locked(
    Output(
      address.from_verification_key(#""),
      assets.from_lovelace(1_000_000),
      NoDatum,
      None,
    ),
    assets.from_lovelace(5_000_000),
  )
}

// pub fn enough_funds_locked(locked_input: Output, spent_amount: Value) -> Bool {
//   assets.negate(spent_amount)
//     |> assets.merge(locked_input.value)
//     |> assets.reduce(
//         True,
//         fn(_policyId, _assetName, amount, result) { amount >= 0 && result },
//       )
// }

// Testing No Datum Spending Actions
test automatic_payments_succeed_no_datum_withdraw_fail() fail {
  let output_reference = OutputReference("", 0)
  let transaction =
    Transaction { ..placeholder, extra_signatories: [payment_pkh] }
  automatic_payments.automatic_payments.spend(
    #"",
    None,
    Withdraw,
    output_reference,
    transaction,
  )
}

test automatic_payments_succeed_no_datum_execute_payment_fail() fail {
  let output_reference = OutputReference("", 0)
  let transaction =
    Transaction { ..placeholder, extra_signatories: [payment_pkh] }
  automatic_payments.automatic_payments.spend(
    #"",
    None,
    ExecutePayment(0, 0, 0, None),
    output_reference,
    transaction,
  )
}

test automatic_payments_succeed_datum_rescue_funds_fail() fail {
  let datum =
    AutomatedPayment {
      ..datum_template(),
      owner_pkh: payment_pkh,
      start_time: 1719835200000,
    }
  let input =
    Input {
      output_reference: OutputReference("", 0),
      output: Output {
        address: address.from_verification_key(settings_policy_id),
        value: assets.from_asset(settings_policy_id, "settings", 1),
        datum: InlineDatum(Settings(payment_pkh, [], [], 0, 0)),
        reference_script: None,
      },
    }

  let output_reference = OutputReference("", 0)
  let transaction =
    Transaction {
      ..placeholder,
      reference_inputs: [input],
      extra_signatories: [payment_pkh],
    }
  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    RescueFunds,
    output_reference,
    transaction,
  )
}

test automatic_payments_succeed_no_datum_succeed_rescue_funds() {
  let input =
    Input {
      output_reference: OutputReference("", 0),
      output: Output {
        address: address.from_verification_key(settings_policy_id),
        value: assets.from_asset(settings_policy_id, "settings", 1),
        datum: InlineDatum(Settings(payment_pkh, [], [], 0, 0)),
        reference_script: None,
      },
    }

  let output_reference = OutputReference("", 0)
  let transaction =
    Transaction {
      ..placeholder,
      reference_inputs: [input],
      extra_signatories: [payment_pkh],
    }
  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    None,
    RescueFunds,
    output_reference,
    transaction,
  )
}

test serialise_settings_policy_id() {
  trace cbor.serialise(
    #"d8eba846aaef90ff9a5c23c4648695d10707d9a5a27df121c11e3961",
  )
  True
}
