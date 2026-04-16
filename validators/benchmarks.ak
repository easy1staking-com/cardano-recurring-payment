use aiken/interval.{between}
use automatic_payments
use cardano/address
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}
use types/automatic_payments.{
  AssetAmount, AutomatedPayment, ExecutePayment, RescueFunds, Settings, Withdraw,
} as automatic_payments_types

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const owner_pkh = #"4f0f62955aaac98d8ffc1d26279cfafc9cbf46f44225e269bbe29560"

const operator_pkh =
  #"018f6b977da177061ad00cf4ef14f429ebc7befb40a843314e7575d9"

const payee_pkh =
  #"869423edf942154f9a965a51a06639a2645f23a67fe849ecbe8762b4"

const staking_pkh =
  #"420268df8f2f20358ff8305836ed590ab691b7263e28ea5d60b4ac51"

const script_hash =
  #"aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd"

const settings_policy_id =
  #"11111111111111111111111111111111111111111111111111111111"

const policy_a = #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const token_a = #"746f6b656e41"

const base_time = 1721163789000

const validity_start = 1721164509000

const validity_end = 1721165409000

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn script_address() -> address.Address {
  address.from_script(script_hash)
    |> address.with_delegation_key(staking_pkh)
}

fn payee_address() -> address.Address {
  address.from_verification_key(payee_pkh)
    |> address.with_delegation_key(staking_pkh)
}

fn settings_ref_input(settings: Settings) -> Input {
  Input {
    output_reference: OutputReference(#"ee", 0),
    output: Output {
      address: address.from_script(settings_policy_id),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(settings_policy_id, "settings", 1),
      datum: InlineDatum(settings),
      reference_script: None,
    },
  }
}

fn default_settings() -> Settings {
  Settings {
    setting_admin_pkh: operator_pkh,
    authorised_operators: [operator_pkh],
    operator_fee_exempt_users: [],
    operator_fee_lovelace: 1_000_000,
    base_fee_lovelace: 360_000,
  }
}

fn wallet_input() -> Input {
  Input {
    output_reference: OutputReference(#"ff", 0),
    output: Output {
      address: address.from_verification_key(operator_pkh),
      value: assets.from_lovelace(10_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

fn script_input(datum: AutomatedPayment, locked_value: assets.Value) -> Input {
  Input {
    output_reference: OutputReference(#"aa", 0),
    output: Output {
      address: script_address(),
      value: locked_value,
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

fn validity_range() {
  between(validity_start, validity_end)
}

// ---------------------------------------------------------------------------
// Benchmark: Withdraw
// ---------------------------------------------------------------------------

test bench_withdraw() {
  let datum =
    AutomatedPayment {
      owner_pkh,
      amount_to_send: [AssetAmount(#"", #"", 2_000_000)],
      payee: payee_address(),
      start_time: base_time,
      end_time: None,
      payment_interval_hours: Some(24),
      max_payment_delay_hours: None,
      max_fees_lovelace: 2_000_000,
    }
  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    Withdraw,
    OutputReference(#"aa", 0),
    Transaction { ..placeholder, extra_signatories: [owner_pkh] },
  )
}

// ---------------------------------------------------------------------------
// Benchmark: RescueFunds
// ---------------------------------------------------------------------------

test bench_rescue_funds() {
  let settings = default_settings()
  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    None,
    RescueFunds,
    OutputReference(#"aa", 0),
    Transaction {
      ..placeholder,
      reference_inputs: [settings_ref_input(settings)],
      extra_signatories: [operator_pkh],
    },
  )
}

// ---------------------------------------------------------------------------
// Benchmark: ExecutePayment — one-time ADA only
// ---------------------------------------------------------------------------

test bench_execute_one_time_ada() {
  let settings = default_settings()
  let datum =
    AutomatedPayment {
      owner_pkh,
      amount_to_send: [AssetAmount(#"", #"", 2_000_000)],
      payee: payee_address(),
      start_time: base_time,
      end_time: None,
      payment_interval_hours: None,
      max_payment_delay_hours: None,
      max_fees_lovelace: 2_000_000,
    }
  let locked_value = assets.from_lovelace(10_000_000)
  let own_input = script_input(datum, locked_value)

  let payee_output =
    Output {
      address: payee_address(),
      value: assets.from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [own_input, wallet_input()],
      reference_inputs: [settings_ref_input(settings)],
      outputs: [payee_output],
      validity_range: validity_range(),
      extra_signatories: [operator_pkh],
    }

  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    ExecutePayment {
      in_index: 0,
      num_batch_payments: 1,
      operator_index: 0,
      fee_exempt_user_index: None,
    },
    own_input.output_reference,
    tx,
  )
}

// ---------------------------------------------------------------------------
// Benchmark: ExecutePayment — recurring ADA only
// ---------------------------------------------------------------------------

test bench_execute_recurring_ada() {
  let settings = default_settings()
  let total_fees = 1_360_000
  let payment_amount = 2_000_000
  let locked_amount = 50_000_000
  let returning_amount = locked_amount - payment_amount - total_fees

  let datum =
    AutomatedPayment {
      owner_pkh,
      amount_to_send: [AssetAmount(#"", #"", payment_amount)],
      payee: payee_address(),
      start_time: base_time,
      end_time: None,
      payment_interval_hours: Some(24),
      max_payment_delay_hours: None,
      max_fees_lovelace: 2_000_000,
    }
  let locked_value = assets.from_lovelace(locked_amount)
  let own_input = script_input(datum, locked_value)

  // new start_time: k = (validity_start - base_time) / (24*3600000) + 1
  // k = (1721164509000 - 1721163789000) / 86400000 + 1 = 0 + 1 = 1
  // new_start = base_time + 1 * 86400000 = 1721163789000 + 86400000 = 1721250189000
  let new_start_time = 1721250189000

  let returning_datum = AutomatedPayment { ..datum, start_time: new_start_time }

  let payee_output =
    Output {
      address: payee_address(),
      value: assets.from_lovelace(payment_amount),
      datum: NoDatum,
      reference_script: None,
    }
  let returning_output =
    Output {
      address: script_address(),
      value: assets.from_lovelace(returning_amount),
      datum: InlineDatum(returning_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [own_input, wallet_input()],
      reference_inputs: [settings_ref_input(settings)],
      outputs: [payee_output, returning_output],
      validity_range: validity_range(),
      extra_signatories: [operator_pkh],
    }

  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    ExecutePayment {
      in_index: 0,
      num_batch_payments: 1,
      operator_index: 0,
      fee_exempt_user_index: None,
    },
    own_input.output_reference,
    tx,
  )
}

// ---------------------------------------------------------------------------
// Benchmark: ExecutePayment — recurring ADA + native token
// ---------------------------------------------------------------------------

test bench_execute_recurring_ada_and_token() {
  let settings = default_settings()
  let total_fees = 1_360_000
  let payment_ada = 2_000_000
  let payment_token = 5_000_000
  let locked_ada = 50_000_000
  let locked_token = 30_000_000
  let returning_ada = locked_ada - payment_ada - total_fees
  let returning_token = locked_token - payment_token

  let datum =
    AutomatedPayment {
      owner_pkh,
      amount_to_send: [
        AssetAmount(#"", #"", payment_ada),
        AssetAmount(policy_a, token_a, payment_token),
      ],
      payee: payee_address(),
      start_time: base_time,
      end_time: None,
      payment_interval_hours: Some(24),
      max_payment_delay_hours: None,
      max_fees_lovelace: 2_000_000,
    }
  let locked_value =
    assets.from_lovelace(locked_ada)
      |> assets.add(policy_a, token_a, locked_token)
  let own_input = script_input(datum, locked_value)

  let new_start_time = 1721250189000
  let returning_datum = AutomatedPayment { ..datum, start_time: new_start_time }

  let payee_output =
    Output {
      address: payee_address(),
      value: assets.from_lovelace(payment_ada)
        |> assets.add(policy_a, token_a, payment_token),
      datum: NoDatum,
      reference_script: None,
    }
  let returning_output =
    Output {
      address: script_address(),
      value: assets.from_lovelace(returning_ada)
        |> assets.add(policy_a, token_a, returning_token),
      datum: InlineDatum(returning_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [own_input, wallet_input()],
      reference_inputs: [settings_ref_input(settings)],
      outputs: [payee_output, returning_output],
      validity_range: validity_range(),
      extra_signatories: [operator_pkh],
    }

  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    ExecutePayment {
      in_index: 0,
      num_batch_payments: 1,
      operator_index: 0,
      fee_exempt_user_index: None,
    },
    own_input.output_reference,
    tx,
  )
}

// ---------------------------------------------------------------------------
// Benchmark: ExecutePayment — recurring with max_payment_delay + end_time
// ---------------------------------------------------------------------------

test bench_execute_recurring_with_constraints() {
  let settings = default_settings()
  let total_fees = 1_360_000
  let payment_amount = 2_000_000
  let locked_amount = 50_000_000
  let returning_amount = locked_amount - payment_amount - total_fees

  let datum =
    AutomatedPayment {
      owner_pkh,
      amount_to_send: [AssetAmount(#"", #"", payment_amount)],
      payee: payee_address(),
      start_time: base_time,
      end_time: Some(base_time + 30 * 86_400_000),
      payment_interval_hours: Some(24),
      max_payment_delay_hours: Some(12),
      max_fees_lovelace: 2_000_000,
    }
  let locked_value = assets.from_lovelace(locked_amount)
  let own_input = script_input(datum, locked_value)

  let new_start_time = 1721250189000
  let returning_datum = AutomatedPayment { ..datum, start_time: new_start_time }

  let payee_output =
    Output {
      address: payee_address(),
      value: assets.from_lovelace(payment_amount),
      datum: NoDatum,
      reference_script: None,
    }
  let returning_output =
    Output {
      address: script_address(),
      value: assets.from_lovelace(returning_amount),
      datum: InlineDatum(returning_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [own_input, wallet_input()],
      reference_inputs: [settings_ref_input(settings)],
      outputs: [payee_output, returning_output],
      validity_range: validity_range(),
      extra_signatories: [operator_pkh],
    }

  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    ExecutePayment {
      in_index: 0,
      num_batch_payments: 1,
      operator_index: 0,
      fee_exempt_user_index: None,
    },
    own_input.output_reference,
    tx,
  )
}

// ---------------------------------------------------------------------------
// Benchmark: ExecutePayment — fee-exempt user
// ---------------------------------------------------------------------------

test bench_execute_recurring_fee_exempt() {
  let settings =
    Settings {
      ..default_settings(),
      operator_fee_exempt_users: [owner_pkh],
    }
  // fee exempt: no operator fee, only base fee
  let total_fees = 360_000
  let payment_amount = 2_000_000
  let locked_amount = 50_000_000
  let returning_amount = locked_amount - payment_amount - total_fees

  let datum =
    AutomatedPayment {
      owner_pkh,
      amount_to_send: [AssetAmount(#"", #"", payment_amount)],
      payee: payee_address(),
      start_time: base_time,
      end_time: None,
      payment_interval_hours: Some(24),
      max_payment_delay_hours: None,
      max_fees_lovelace: 2_000_000,
    }
  let locked_value = assets.from_lovelace(locked_amount)
  let own_input = script_input(datum, locked_value)

  let new_start_time = 1721250189000
  let returning_datum = AutomatedPayment { ..datum, start_time: new_start_time }

  let payee_output =
    Output {
      address: payee_address(),
      value: assets.from_lovelace(payment_amount),
      datum: NoDatum,
      reference_script: None,
    }
  let returning_output =
    Output {
      address: script_address(),
      value: assets.from_lovelace(returning_amount),
      datum: InlineDatum(returning_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      ..placeholder,
      inputs: [own_input, wallet_input()],
      reference_inputs: [settings_ref_input(settings)],
      outputs: [payee_output, returning_output],
      validity_range: validity_range(),
      extra_signatories: [operator_pkh],
    }

  automatic_payments.automatic_payments.spend(
    settings_policy_id,
    Some(datum),
    ExecutePayment {
      in_index: 0,
      num_batch_payments: 1,
      operator_index: 0,
      fee_exempt_user_index: Some(0),
    },
    own_input.output_reference,
    tx,
  )
}

// ---------------------------------------------------------------------------
// Benchmark: ExecutePayment — batch of 3 recurring ADA payments
// ---------------------------------------------------------------------------

test bench_execute_batch_3_recurring_ada() {
  let settings = default_settings()
  let total_fees = 1_360_000
  let payment_amount = 2_000_000
  let locked_amount = 50_000_000
  let returning_amount = locked_amount - payment_amount - total_fees
  let new_start_time = 1721250189000

  let make_datum =
    fn() {
      AutomatedPayment {
        owner_pkh,
        amount_to_send: [AssetAmount(#"", #"", payment_amount)],
        payee: payee_address(),
        start_time: base_time,
        end_time: None,
        payment_interval_hours: Some(24),
        max_payment_delay_hours: None,
        max_fees_lovelace: 2_000_000,
      }
    }

  let datum_1 = make_datum()
  let datum_2 = make_datum()
  let datum_3 = make_datum()

  let input_1 =
    Input {
      output_reference: OutputReference(#"aa", 0),
      output: Output {
        address: script_address(),
        value: assets.from_lovelace(locked_amount),
        datum: InlineDatum(datum_1),
        reference_script: None,
      },
    }
  let input_2 =
    Input {
      output_reference: OutputReference(#"aa", 1),
      output: Output {
        address: script_address(),
        value: assets.from_lovelace(locked_amount),
        datum: InlineDatum(datum_2),
        reference_script: None,
      },
    }
  let input_3 =
    Input {
      output_reference: OutputReference(#"aa", 2),
      output: Output {
        address: script_address(),
        value: assets.from_lovelace(locked_amount),
        datum: InlineDatum(datum_3),
        reference_script: None,
      },
    }

  let make_payee_output =
    fn() {
      Output {
        address: payee_address(),
        value: assets.from_lovelace(payment_amount),
        datum: NoDatum,
        reference_script: None,
      }
    }

  let make_returning_output =
    fn(datum: AutomatedPayment) {
      Output {
        address: script_address(),
        value: assets.from_lovelace(returning_amount),
        datum: InlineDatum(
          AutomatedPayment { ..datum, start_time: new_start_time },
        ),
        reference_script: None,
      }
    }

  // outputs layout: [payee_0, payee_1, payee_2, returning_0, returning_1, returning_2]
  let tx =
    Transaction {
      ..placeholder,
      inputs: [input_1, input_2, input_3, wallet_input()],
      reference_inputs: [settings_ref_input(settings)],
      outputs: [
        make_payee_output(),
        make_payee_output(),
        make_payee_output(),
        make_returning_output(datum_1),
        make_returning_output(datum_2),
        make_returning_output(datum_3),
      ],
      validity_range: validity_range(),
      extra_signatories: [operator_pkh],
    }

  // Validate first input (in_index=0, num_batch_payments=3)
  let r1 =
    automatic_payments.automatic_payments.spend(
      settings_policy_id,
      Some(datum_1),
      ExecutePayment {
        in_index: 0,
        num_batch_payments: 3,
        operator_index: 0,
        fee_exempt_user_index: None,
      },
      input_1.output_reference,
      tx,
    )
  // Validate second input
  let r2 =
    automatic_payments.automatic_payments.spend(
      settings_policy_id,
      Some(datum_2),
      ExecutePayment {
        in_index: 1,
        num_batch_payments: 3,
        operator_index: 0,
        fee_exempt_user_index: None,
      },
      input_2.output_reference,
      tx,
    )
  // Validate third input
  let r3 =
    automatic_payments.automatic_payments.spend(
      settings_policy_id,
      Some(datum_3),
      ExecutePayment {
        in_index: 2,
        num_batch_payments: 3,
        operator_index: 0,
        fee_exempt_user_index: None,
      },
      input_3.output_reference,
      tx,
    )

  and {
    r1,
    r2,
    r3,
  }
}
