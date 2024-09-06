use aiken/interval.{after, between}
use automatic_payments.{
  automatic_payments, compute_new_start_time, configuration_nft,
  is_payment_time_valid, is_right_amount_sent_to_payee, load_configuration,
}
use cardano/assets.{Value, merge, zero}
use tests/fixtures.{datum_template}
use types/automatic_payments.{
  Configuration, Daily, Datum, Days, Hourly, Weeks, Withdraw,
} as automatic_payments_types

const payment_pkh = #"4f0f62955aaac98d8ffc1d26279cfafc9cbf46f44225e269bbe29560"

// const staking_pkh = #"420268df8f2f20358ff8305836ed590ab691b7263e28ea5d60b4ac51"

const payment_pkh_1 =
  #"869423edf942154f9a965a51a06639a2645f23a67fe849ecbe8762b4"

const payee_payment_pkh =
  #"16e080770f227c889e005eb648a831e53bb12f9b87da6a925de7399d"

// const payee_staking_pkh =
//   #"414c2c4e10f6171c57b4fbc6f2fdb10139cd43058092732fcdb3a764"

const bot_payment_pkh =
  #"018f6b977da177061ad00cf4ef14f429ebc7befb40a843314e7575d9"

test automatic_payments_succeed_withdraw() {
  let datum =
    Datum {
      ..datum_template(),
      owner_payment_pkh: payment_pkh,
      start_time: 1719835200000,
    }
  let transaction =
    Transaction {
      ..transaction.placeholder(),
      extra_signatories: [payment_pkh],
    }
  let context =
    ScriptContext {
      purpose: Spend(
        OutputReference { transaction_id: TransactionId(""), output_index: 0 },
      ),
      transaction,
    }
  automatic_payments(datum, Withdraw, context)
}

test automatic_payments_fail_withdraw() {
  let datum =
    Datum {
      ..datum_template(),
      owner_payment_pkh: payment_pkh,
      start_time: 1719835200000,
    }
  let transaction =
    Transaction {
      ..transaction.placeholder(),
      extra_signatories: [payment_pkh_1],
    }
  let context =
    ScriptContext {
      purpose: Spend(
        OutputReference { transaction_id: TransactionId(""), output_index: 0 },
      ),
      transaction,
    }
  !automatic_payments(datum, Withdraw, context)
}

// Validity time/interval tests
test is_payment_time_valid_succeed_start_time_only() {
  let datum = Datum { ..datum_template(), start_time: 1719835200000 }
  is_payment_time_valid(datum, after(1719838800000))
}

test is_payment_time_valid_succeed_start_time_only_interval() {
  let datum = Datum { ..datum_template(), start_time: 1719835200000 }
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_and_max_delay() {
  let datum =
    Datum {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_overlap_and_max_delay() {
  let datum =
    Datum {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  is_payment_time_valid(datum, between(1719835200000, 1719849600000))
}

test is_payment_time_valid_fail_start_time_and_max_delay_overlap() {
  let datum =
    Datum {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  !is_payment_time_valid(datum, between(1719831600000, 1719853200000))
}

test is_payment_time_valid_fail_earlier_start_time() {
  let datum =
    Datum {
      ..datum_template(),
      start_time: 1719835200000,
      max_payment_delay_hours: Some(5),
    }
  !is_payment_time_valid(datum, after(1719831600000))
}

// Add Valid interval test, no max hours and end_time and everything still works
test is_payment_time_valid_succeed_start_time_and_time() {
  let datum =
    Datum {
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
    Datum {
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
    Datum {
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
    Datum {
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
    Hourly,
    between(1721164509000, 1721165409000),
  ) == 1721167389000
}

test compute_new_start_time_1_day() {
  compute_new_start_time(
    1721163789000,
    Daily,
    between(1721164509000, 1721165409000),
  ) == 1721250189000
}

test compute_new_start_time_3_day() {
  compute_new_start_time(
    1721163789000,
    Days(3),
    between(1721164509000, 1721165409000),
  ) == 1721422989000
}

test compute_new_start_time_5_day() {
  compute_new_start_time(
    1721163789000,
    Days(5),
    between(1721164509000, 1721165409000),
  ) == 1721595789000
}

test compute_new_start_time_2_weeks() {
  compute_new_start_time(
    1721163789000,
    Weeks(2),
    between(1721164509000, 1721165409000),
  ) == 1722373389000
}

test compute_new_start_time_end_time_skip_1h() {
  compute_new_start_time(
    1721163789000,
    Hourly,
    between(1721167809000, 1721169009000),
  ) == 1721170989000
}

test is_right_amount_sent_to_payee_succeed_0_value() {
  let payee_address =
    Address {
      payment_credential: VerificationKeyCredential(payee_payment_pkh),
      stake_credential: None,
    }
  is_right_amount_sent_to_payee(payee_address, [], value.zero())
}

test is_right_amount_sent_to_payee_succeed_some_value() {
  let payee_address =
    Address(VerificationKeyCredential(payee_payment_pkh), None)
  let other_address = Address(VerificationKeyCredential(payment_pkh_1), None)

  let outputs =
    [
      Output {
        address: payee_address,
        value: value.from_lovelace(1_000_000),
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        address: other_address,
        value: value.from_lovelace(10_000_000),
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        address: payee_address,
        value: value.from_lovelace(3_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    ]

  is_right_amount_sent_to_payee(
    payee_address,
    outputs,
    value.from_lovelace(4_000_000),
  )
}

test is_right_amount_sent_to_payee_succeed_some_value_and_asset() {
  let policy = #"a0028f350aaabe0545fdcb56b039bfb08e4bb4d8c4d7c3c7d481c235"
  let asset = #"484f534b59"

  let payee_address =
    Address(VerificationKeyCredential(payee_payment_pkh), None)
  let other_address = Address(VerificationKeyCredential(payment_pkh_1), None)

  let outputs =
    [
      Output {
        address: payee_address,
        value: value.from_lovelace(1_000_000),
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        address: other_address,
        value: value.from_lovelace(10_000_000),
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        address: payee_address,
        value: value.from_lovelace(3_000_000) |> add(policy, asset, 1_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    ]

  let expect_value =
    value.from_lovelace(4_000_000) |> add(policy, asset, 1_000_000)

  is_right_amount_sent_to_payee(payee_address, outputs, expect_value)
}

test is_right_amount_sent_to_payee_fail_different_value() {
  let payee_address =
    Address(VerificationKeyCredential(payee_payment_pkh), None)
  let other_address = Address(VerificationKeyCredential(payment_pkh_1), None)

  let outputs =
    [
      Output {
        address: payee_address,
        value: value.from_lovelace(1_000_000),
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        address: other_address,
        value: value.from_lovelace(10_000_000),
        datum: NoDatum,
        reference_script: None,
      },
      Output {
        address: payee_address,
        value: value.from_lovelace(3_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    ]

  !is_right_amount_sent_to_payee(
    payee_address,
    outputs,
    value.from_lovelace(10_000_000),
  )
}

// Testing Configuration
test load_configuration_fail_no_ref_inputs() fail {
  let transaction: Transaction = transaction.placeholder()
  let configuration = load_configuration(transaction)
  configuration == configuration
}

test load_configuration_fail_missing_configuration_ref_input() fail {
  let address = payment_pkh_1 |> credential.from_verification_key

  let transaction =
    Transaction {
      ..transaction.placeholder(),
      reference_inputs: [
        Input(
          OutputReference(TransactionId(#""), 0),
          Output {
            address,
            value: value.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
      ],
    }

  let configuration = load_configuration(transaction)
  configuration == configuration
}

test load_configuration_fail_no_datum() fail {
  let address = payment_pkh_1 |> credential.from_verification_key

  let transaction =
    Transaction {
      ..transaction.placeholder(),
      reference_inputs: [
        Input(
          OutputReference(TransactionId(#""), 0),
          Output {
            address,
            value: value.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
        Input(
          OutputReference(TransactionId(#""), 0),
          Output {
            address,
            value: value.from_lovelace(10_000_000)
              |> add(configuration_nft, configuration_nft, 1),
            datum: NoDatum,
            reference_script: None,
          },
        ),
      ],
    }

  let configuration = load_configuration(transaction)
  configuration == configuration
}

test load_configuration_succeed() {
  let address = payment_pkh_1 |> credential.from_verification_key
  let expected_configuration = Configuration(bot_payment_pkh, 1_000_000)
  let transaction =
    Transaction {
      ..transaction.placeholder(),
      reference_inputs: [
        Input(
          OutputReference(TransactionId(#""), 0),
          Output {
            address,
            value: value.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        ),
        Input(
          OutputReference(TransactionId(#""), 0),
          Output {
            address,
            value: value.from_lovelace(10_000_000)
              |> add(configuration_nft, configuration_nft, 1),
            datum: InlineDatum(expected_configuration),
            reference_script: None,
          },
        ),
      ],
    }

  let actual_configuration = load_configuration(transaction)
  actual_configuration == expected_configuration
}
