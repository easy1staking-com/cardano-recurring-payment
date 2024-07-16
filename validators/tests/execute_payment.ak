use aiken/interval.{after, between}
use aiken/transaction.{
  NoDatum, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId,
}
use aiken/transaction/credential.{Address, VerificationKeyCredential}
use aiken/transaction/value.{add}
use automatic_payments.{
  Daily, Datum, Days, Hourly, Weeks, Withdraw, automatic_payments,
  compute_new_start_time, is_payment_time_valid, is_right_amount_sent_to_payee,
}

const payment_pkh = #"4f0f62955aaac98d8ffc1d26279cfafc9cbf46f44225e269bbe29560"

// const staking_pkh = #"420268df8f2f20358ff8305836ed590ab691b7263e28ea5d60b4ac51"

const payment_pkh_1 =
  #"869423edf942154f9a965a51a06639a2645f23a67fe849ecbe8762b4"

const payee_payment_pkh =
  #"16e080770f227c889e005eb648a831e53bb12f9b87da6a925de7399d"

// const payee_staking_pkh =
//   #"414c2c4e10f6171c57b4fbc6f2fdb10139cd43058092732fcdb3a764"

test automatic_payments_succeed_withdraw() {
  let datum =
    Datum(
      payment_pkh,
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      None,
      #"",
    )
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
    Datum(
      payment_pkh,
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      None,
      #"",
    )
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

test is_payment_time_valid_succeed_start_time_only() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      None,
      #"",
    )
  is_payment_time_valid(datum, after(1719838800000))
}

test is_payment_time_valid_succeed_start_time_only_interval() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      None,
      #"",
    )
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_and_max_delay() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_overlap_and_max_delay() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  is_payment_time_valid(datum, between(1719835200000, 1719849600000))
}

test is_payment_time_valid_fail_start_time_and_max_delay_overlap() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  !is_payment_time_valid(datum, between(1719831600000, 1719853200000))
}

test is_payment_time_valid_fail_earlier_start_time() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  !is_payment_time_valid(datum, after(1719831600000))
}

test compute_new_start_time_1_hour() {
  compute_new_start_time(1721163789000, Hourly) == 1721167389000
}

test compute_new_start_time_1_day() {
  compute_new_start_time(1721163789000, Daily) == 1721250189000
}

test compute_new_start_time_3_day() {
  compute_new_start_time(1721163789000, Days(3)) == 1721422989000
}

test compute_new_start_time_5_day() {
  compute_new_start_time(1721163789000, Days(5)) == 1721595789000
}

test compute_new_start_time_2_weeks() {
  compute_new_start_time(1721163789000, Weeks(2)) == 1722373389000
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
