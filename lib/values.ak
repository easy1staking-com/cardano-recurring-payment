use aiken/builtin.{equals_bytearray, head_list, tail_list}
use aiken/collection/dict.{Dict}
use cardano/assets.{AssetName, PolicyId, Value}

pub fn greater_than(left: Value, right: Value) -> Bool {
  let left_policies = assets.to_dict(left) |> dict.to_pairs()
  let right_policies = assets.to_dict(right) |> dict.to_pairs()
  check_policies(left_policies, right_policies)
}

/// Subtract `value` from `self`, returning the remaining `Value`.
/// Crashes if any asset in `self` would go negative.
pub fn debit(self: Value, value: Value) -> Value {
  let self_policies = assets.to_dict(self) |> dict.to_pairs()
  let value_policies = assets.to_dict(value) |> dict.to_pairs()
  debit_policies(self_policies, value_policies)
    |> assets.from_asset_list()
}

fn debit_policies(
  self: Pairs<ByteArray, Dict<AssetName, Int>>,
  value: Pairs<ByteArray, Dict<AssetName, Int>>,
) -> Pairs<PolicyId, Pairs<AssetName, Int>> {
  when value is {
    [] -> keep_remaining_policies(self)
    [v_head, ..v_tail] ->
      drain_policy_until(self, v_head.1st, v_head.2nd, v_tail)
  }
}

fn keep_remaining_policies(
  self: Pairs<ByteArray, Dict<AssetName, Int>>,
) -> Pairs<PolicyId, Pairs<AssetName, Int>> {
  when self is {
    [] -> []
    [head, ..tail] ->
      [Pair(head.1st, dict.to_pairs(head.2nd)), ..keep_remaining_policies(tail)]
  }
}

fn drain_policy_until(
  self: Pairs<ByteArray, Dict<AssetName, Int>>,
  v_pid: ByteArray,
  v_inner: Dict<AssetName, Int>,
  v_rest: Pairs<ByteArray, Dict<AssetName, Int>>,
) -> Pairs<PolicyId, Pairs<AssetName, Int>> {
  let s_head = head_list(self)
  let s_tail = tail_list(self)
  if equals_bytearray(s_head.1st, v_pid) {
    let result = debit_assets(dict.to_pairs(s_head.2nd), dict.to_pairs(v_inner))
    let rest = debit_policies(s_tail, v_rest)
    when result is {
      [] -> rest
      _ -> [Pair(v_pid, result), ..rest]
    }
  } else {
    [
      Pair(s_head.1st, dict.to_pairs(s_head.2nd)),
      ..drain_policy_until(s_tail, v_pid, v_inner, v_rest)
    ]
  }
}

fn debit_assets(
  self: Pairs<ByteArray, Int>,
  value: Pairs<ByteArray, Int>,
) -> Pairs<AssetName, Int> {
  when value is {
    [] -> self
    [v_head, ..v_tail] ->
      drain_asset_until(self, v_head.1st, v_head.2nd, v_tail)
  }
}

fn drain_asset_until(
  self: Pairs<ByteArray, Int>,
  v_name: ByteArray,
  v_amount: Int,
  v_rest: Pairs<ByteArray, Int>,
) -> Pairs<AssetName, Int> {
  let s_head = head_list(self)
  let s_tail = tail_list(self)
  if equals_bytearray(s_head.1st, v_name) {
    let diff = s_head.2nd - v_amount
    expect diff >= 0
    let rest = debit_assets(s_tail, v_rest)
    if diff == 0 {
      rest
    } else {
      [Pair(v_name, diff), ..rest]
    }
  } else {
    [
      Pair(s_head.1st, s_head.2nd),
      ..drain_asset_until(s_tail, v_name, v_amount, v_rest)
    ]
  }
}

fn check_policies(
  left: Pairs<ByteArray, Dict<AssetName, Int>>,
  right: Pairs<ByteArray, Dict<AssetName, Int>>,
) -> Bool {
  when right is {
    [] -> True
    [head_right, ..tail_right] -> {
      let left_assets, rest_left <-
        pop_until(left, equals_bytearray(head_right.1st, _))
      contains(dict.to_pairs(left_assets), dict.to_pairs(head_right.2nd))
        && check_policies(rest_left, tail_right)
    }
  }
}

/// /!\ PRE-CONDITION /!\
/// Given pairs are assumed to be well-formed and semantically 'correct'. That
/// is, keys contain no duplicates and are in ascending order.
///
/// In practice, this means we suppose both values have been constructed from
/// existing well-formed Values.
pub fn contains(
  superset: Pairs<AssetName, Int>,
  subset: Pairs<AssetName, Int>,
) -> Bool {
  when subset is {
    [] -> True
    [head_subset, ..tail_subset] -> {
      let
        head_superset,
        tail_superset,
      <- pop_until(superset, equals_bytearray(head_subset.1st, _))
      and {
        head_superset >= head_subset.2nd,
        contains(tail_superset, tail_subset),
      }
    }
  }
}

/// Drop elements from an associative list until a given key is encountered. Fails loudly otherwise.
/// Returns the value at that key, and the rest of the list.
pub fn pop_until(
  self: Pairs<ByteArray, v>,
  until: fn(ByteArray) -> Bool,
  return: fn(v, Pairs<ByteArray, v>) -> result,
) -> result {
  let head = head_list(self)
  if until(head.1st) {
    return(head.2nd, tail_list(self))
  } else {
    pop_until(tail_list(self), until, return)
  }
}
