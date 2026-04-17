use aiken/interval.{between}
use cardano/address
use cardano/assets
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use oracle.{
  AggState, GenericData, OraclePrice, ceil_div, compute_oracle_payment_amount,
  load_oracle_price, validate_oracle_freshness, validate_price_bounds,
}

const oracle_policy =
  #"886dcb2363e160c944e63cf544ce6f6265b22ef7c4e2478dd975078e"

fn mk_oracle_input(
  policy_id: ByteArray,
  price: Int,
  creation_time: Int,
  expiration_time: Int,
) -> Input {
  Input {
    output_reference: OutputReference(#"cc", 0),
    output: Output {
      address: address.from_script(#"dd"),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(policy_id, "C3AS", 1),
      datum: InlineDatum(
        AggState(
          GenericData {
            price_map: [
              Pair(0, price),
              Pair(1, creation_time),
              Pair(2, expiration_time),
            ],
          },
        ),
      ),
      reference_script: None,
    },
  }
}

// ---------------------------------------------------------------------------
// load_oracle_price
// ---------------------------------------------------------------------------

test load_oracle_price_succeed() {
  let ref_input = mk_oracle_input(oracle_policy, 400_000, 1000, 2000)
  let result = load_oracle_price([ref_input], oracle_policy)
  and {
    result.price == 400_000,
    result.creation_time == 1000,
    result.expiration_time == 2000,
  }
}

test load_oracle_price_fail_no_nft() fail {
  let result = load_oracle_price([], oracle_policy)
  result == result
}

test load_oracle_price_fail_wrong_policy() fail {
  let ref_input = mk_oracle_input(#"aabb", 400_000, 1000, 2000)
  let result = load_oracle_price([ref_input], oracle_policy)
  result == result
}

test load_oracle_price_fail_no_datum() fail {
  let ref_input =
    Input {
      output_reference: OutputReference(#"cc", 0),
      output: Output {
        address: address.from_script(#"dd"),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(oracle_policy, "C3AS", 1),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let result = load_oracle_price([ref_input], oracle_policy)
  result == result
}

test load_oracle_price_fail_zero_price() fail {
  let ref_input = mk_oracle_input(oracle_policy, 0, 1000, 2000)
  let result = load_oracle_price([ref_input], oracle_policy)
  result == result
}

test load_oracle_price_fail_negative_price() fail {
  let ref_input = mk_oracle_input(oracle_policy, -100, 1000, 2000)
  let result = load_oracle_price([ref_input], oracle_policy)
  result == result
}

// ---------------------------------------------------------------------------
// validate_oracle_freshness
// ---------------------------------------------------------------------------

test validate_freshness_succeed() {
  let oracle = OraclePrice { price: 400_000, creation_time: 1000, expiration_time: 5000 }
  validate_oracle_freshness(oracle, between(2000, 3000), None)
}

test validate_freshness_fail_expired() {
  let oracle = OraclePrice { price: 400_000, creation_time: 1000, expiration_time: 1500 }
  !validate_oracle_freshness(oracle, between(2000, 3000), None)
}

test validate_freshness_succeed_with_max_age() {
  let oracle = OraclePrice { price: 400_000, creation_time: 1000, expiration_time: 5000 }
  // tx_earliest = 2000, creation = 1000, age = 1000, max_age = 2000
  validate_oracle_freshness(oracle, between(2000, 3000), Some(2000))
}

test validate_freshness_fail_too_old() {
  let oracle = OraclePrice { price: 400_000, creation_time: 1000, expiration_time: 5000 }
  // tx_earliest = 2000, creation = 1000, age = 1000, max_age = 500
  !validate_oracle_freshness(oracle, between(2000, 3000), Some(500))
}

// ---------------------------------------------------------------------------
// validate_price_bounds
// ---------------------------------------------------------------------------

test validate_bounds_no_bounds() {
  validate_price_bounds(400_000, None, None)
}

test validate_bounds_within() {
  validate_price_bounds(400_000, Some(300_000), Some(500_000))
}

test validate_bounds_below_min() {
  !validate_price_bounds(200_000, Some(300_000), None)
}

test validate_bounds_above_max() {
  !validate_price_bounds(600_000, None, Some(500_000))
}

test validate_bounds_at_min() {
  validate_price_bounds(300_000, Some(300_000), None)
}

test validate_bounds_at_max() {
  validate_price_bounds(500_000, None, Some(500_000))
}

// ---------------------------------------------------------------------------
// compute_oracle_payment_amount
// ---------------------------------------------------------------------------

// $100 at $0.40/ADA = 250 ADA = 250_000_000 lovelace
test compute_amount_100_usd_at_040() {
  compute_oracle_payment_amount(100_000_000, 400_000) == 250_000_000
}

// $50 at $0.50/ADA = 100 ADA = 100_000_000 lovelace
test compute_amount_50_usd_at_050() {
  compute_oracle_payment_amount(50_000_000, 500_000) == 100_000_000
}

// $1 at $0.30/ADA → ceil(1_000_000 * 1_000_000 / 300_000) = ceil(3333333.33) = 3_333_334
test compute_amount_ceiling_rounding() {
  compute_oracle_payment_amount(1_000_000, 300_000) == 3_333_334
}

// Exact division: $10 at $0.50/ADA = 20 ADA
test compute_amount_exact_division() {
  compute_oracle_payment_amount(10_000_000, 500_000) == 20_000_000
}

// ---------------------------------------------------------------------------
// ceil_div
// ---------------------------------------------------------------------------

test ceil_div_exact() {
  ceil_div(10, 5) == 2
}

test ceil_div_rounds_up() {
  ceil_div(11, 5) == 3
}

test ceil_div_one() {
  ceil_div(1, 3) == 1
}

test ceil_div_large() {
  ceil_div(1_000_000_000_000, 3) == 333_333_333_334
}
