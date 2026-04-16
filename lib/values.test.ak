use cardano/assets
use values.{debit, greater_than}

// --- Both sides empty ---

test greater_than_both_zero() {
  greater_than(assets.zero, assets.zero)
}

// --- Right is zero ---

test greater_than_left_ada_right_zero() {
  greater_than(assets.from_lovelace(5_000_000), assets.zero)
}

// --- Lovelace only ---

test greater_than_ada_gt() {
  greater_than(
    assets.from_lovelace(5_000_000),
    assets.from_lovelace(3_000_000),
  )
}

test greater_than_ada_eq() {
  greater_than(
    assets.from_lovelace(5_000_000),
    assets.from_lovelace(5_000_000),
  )
}

test greater_than_ada_lt() {
  !greater_than(
    assets.from_lovelace(3_000_000),
    assets.from_lovelace(5_000_000),
  )
}

// --- Single native token ---

const policy_a = #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const token_a = #"746f6b656e41"

test greater_than_token_gt() {
  greater_than(
    assets.from_asset(policy_a, token_a, 100),
    assets.from_asset(policy_a, token_a, 50),
  )
}

test greater_than_token_eq() {
  greater_than(
    assets.from_asset(policy_a, token_a, 100),
    assets.from_asset(policy_a, token_a, 100),
  )
}

test greater_than_token_lt() {
  !greater_than(
    assets.from_asset(policy_a, token_a, 50),
    assets.from_asset(policy_a, token_a, 100),
  )
}

// --- Mixed lovelace + token ---

test greater_than_ada_and_token_both_sufficient() {
  let left =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
  let right =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
  greater_than(left, right)
}

test greater_than_ada_sufficient_token_insufficient() {
  let left =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 10)
  let right =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
  !greater_than(left, right)
}

test greater_than_ada_insufficient_token_sufficient() {
  let left =
    assets.from_lovelace(1_000_000)
      |> assets.add(policy_a, token_a, 100)
  let right =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 50)
  !greater_than(left, right)
}

// --- Left has extra policies not in right (surplus is fine) ---

const policy_b = #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const token_b = #"746f6b656e42"

test greater_than_left_has_extra_policy() {
  let left =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
      |> assets.add(policy_b, token_b, 200)
  let right = assets.from_lovelace(3_000_000)
  greater_than(left, right)
}

// --- Right has policy not in left (must fail) ---

test greater_than_right_has_missing_policy() fail {
  let left = assets.from_lovelace(5_000_000)
  let right =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
  greater_than(left, right)
}

// --- Multiple tokens under same policy ---

const token_a2 = #"746f6b656e4132"

test greater_than_multiple_tokens_same_policy() {
  let left =
    assets.from_asset(policy_a, token_a, 100)
      |> assets.add(policy_a, token_a2, 200)
  let right =
    assets.from_asset(policy_a, token_a, 50)
      |> assets.add(policy_a, token_a2, 100)
  greater_than(left, right)
}

test greater_than_multiple_tokens_one_insufficient() {
  let left =
    assets.from_asset(policy_a, token_a, 100)
      |> assets.add(policy_a, token_a2, 30)
  let right =
    assets.from_asset(policy_a, token_a, 50)
      |> assets.add(policy_a, token_a2, 100)
  !greater_than(left, right)
}

// --- Multiple policies ---

test greater_than_multiple_policies_all_sufficient() {
  let left =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
      |> assets.add(policy_b, token_b, 200)
  let right =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
      |> assets.add(policy_b, token_b, 100)
  greater_than(left, right)
}

test greater_than_multiple_policies_second_insufficient() {
  let left =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
      |> assets.add(policy_b, token_b, 10)
  let right =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
      |> assets.add(policy_b, token_b, 100)
  !greater_than(left, right)
}

// --- Right only has tokens (no ada) ---

test greater_than_right_token_only() {
  let left =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
  let right = assets.from_asset(policy_a, token_a, 50)
  greater_than(left, right)
}

// ===========================================================================
// debit tests
// ===========================================================================

// --- Both sides empty ---

test debit_both_zero() {
  debit(assets.zero, assets.zero) == assets.zero
}

// --- Subtract zero ---

test debit_value_is_zero() {
  let self = assets.from_lovelace(5_000_000)
  debit(self, assets.zero) == self
}

// --- Lovelace only ---

test debit_ada_partial() {
  debit(assets.from_lovelace(5_000_000), assets.from_lovelace(3_000_000)) == assets.from_lovelace(
    2_000_000,
  )
}

test debit_ada_exact() {
  debit(assets.from_lovelace(5_000_000), assets.from_lovelace(5_000_000)) == assets.zero
}

test debit_ada_insufficient() fail {
  debit(assets.from_lovelace(3_000_000), assets.from_lovelace(5_000_000)) == assets.zero
}

// --- Single native token ---

test debit_token_partial() {
  debit(
    assets.from_asset(policy_a, token_a, 100),
    assets.from_asset(policy_a, token_a, 40),
  ) == assets.from_asset(policy_a, token_a, 60)
}

test debit_token_exact() {
  debit(
    assets.from_asset(policy_a, token_a, 100),
    assets.from_asset(policy_a, token_a, 100),
  ) == assets.zero
}

test debit_token_insufficient() fail {
  debit(
    assets.from_asset(policy_a, token_a, 50),
    assets.from_asset(policy_a, token_a, 100),
  ) == assets.zero
}

// --- Mixed lovelace + token ---

test debit_ada_and_token() {
  let self =
    assets.from_lovelace(10_000_000)
      |> assets.add(policy_a, token_a, 100)
  let value =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 40)
  let expected =
    assets.from_lovelace(7_000_000)
      |> assets.add(policy_a, token_a, 60)
  debit(self, value) == expected
}

test debit_ada_ok_token_insufficient() fail {
  let self =
    assets.from_lovelace(10_000_000)
      |> assets.add(policy_a, token_a, 10)
  let value =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
  debit(self, value) == assets.zero
}

// --- Self has extra policies (surplus preserved) ---

test debit_keeps_surplus_policies() {
  let self =
    assets.from_lovelace(10_000_000)
      |> assets.add(policy_a, token_a, 100)
      |> assets.add(policy_b, token_b, 200)
  let value = assets.from_lovelace(3_000_000)
  let expected =
    assets.from_lovelace(7_000_000)
      |> assets.add(policy_a, token_a, 100)
      |> assets.add(policy_b, token_b, 200)
  debit(self, value) == expected
}

// --- Value has policy not in self (must crash) ---

test debit_missing_policy_crashes() fail {
  let self = assets.from_lovelace(5_000_000)
  let value =
    assets.from_lovelace(3_000_000)
      |> assets.add(policy_a, token_a, 50)
  debit(self, value) == assets.zero
}

// --- Multiple tokens under same policy ---

test debit_multiple_tokens_same_policy() {
  let self =
    assets.from_asset(policy_a, token_a, 100)
      |> assets.add(policy_a, token_a2, 200)
  let value =
    assets.from_asset(policy_a, token_a, 30)
      |> assets.add(policy_a, token_a2, 50)
  let expected =
    assets.from_asset(policy_a, token_a, 70)
      |> assets.add(policy_a, token_a2, 150)
  debit(self, value) == expected
}

test debit_one_token_exact_other_partial() {
  let self =
    assets.from_asset(policy_a, token_a, 100)
      |> assets.add(policy_a, token_a2, 200)
  let value =
    assets.from_asset(policy_a, token_a, 100)
      |> assets.add(policy_a, token_a2, 50)
  // token_a goes to zero (removed), token_a2 remains
  debit(self, value) == assets.from_asset(policy_a, token_a2, 150)
}

// --- Multiple policies ---

test debit_multiple_policies() {
  let self =
    assets.from_lovelace(10_000_000)
      |> assets.add(policy_a, token_a, 100)
      |> assets.add(policy_b, token_b, 200)
  let value =
    assets.from_lovelace(4_000_000)
      |> assets.add(policy_a, token_a, 30)
      |> assets.add(policy_b, token_b, 100)
  let expected =
    assets.from_lovelace(6_000_000)
      |> assets.add(policy_a, token_a, 70)
      |> assets.add(policy_b, token_b, 100)
  debit(self, value) == expected
}

// --- Subtract only tokens, no ada ---

test debit_token_only_from_mixed() {
  let self =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
  let value = assets.from_asset(policy_a, token_a, 40)
  let expected =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 60)
  debit(self, value) == expected
}

// --- Full policy zeroed out (policy removed from result) ---

test debit_entire_policy_zeroed() {
  let self =
    assets.from_lovelace(5_000_000)
      |> assets.add(policy_a, token_a, 100)
  let value = assets.from_asset(policy_a, token_a, 100)
  debit(self, value) == assets.from_lovelace(5_000_000)
}

// --- Self has extra tokens in a matched policy (surplus preserved) ---

test debit_keeps_surplus_tokens_in_policy() {
  let self =
    assets.from_asset(policy_a, token_a, 100)
      |> assets.add(policy_a, token_a2, 200)
  let value = assets.from_asset(policy_a, token_a, 30)
  let expected =
    assets.from_asset(policy_a, token_a, 70)
      |> assets.add(policy_a, token_a2, 200)
  debit(self, value) == expected
}
