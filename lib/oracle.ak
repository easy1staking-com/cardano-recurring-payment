use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Finite}
use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Input, ValidityRange}

/// Charli3 oracle NFT token name (AggState).
const oracle_nft_name: ByteArray = "C3AS"

/// Keys in the Charli3 PriceMap.
const price_key: Int = 0

const creation_time_key: Int = 1

const expiration_key: Int = 2

// ---------------------------------------------------------------------------
// Charli3 datum mirror types (must match on-chain constructor indices)
// ---------------------------------------------------------------------------

/// OracleDatum: constructor 0 = AggState
/// (We only need index 0; other variants would follow but aren't required
/// since we `expect` the AggState shape.)
pub type Charli3OracleDatum {
  AggState(Charli3PriceData)
}

/// PriceData: constructor 0 = SharedData, 1 = ExtendedData, 2 = GenericData
/// We need all three to match the constructor indices.
pub type Charli3PriceData {
  SharedData
  ExtendedData
  GenericData { price_map: Pairs<Int, Int> }
}

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub type OraclePrice {
  price: Int,
  creation_time: Int,
  expiration_time: Int,
}

// ---------------------------------------------------------------------------
// Oracle reading
// ---------------------------------------------------------------------------

/// Locate the Charli3 oracle reference input by NFT, decode its datum,
/// and extract the price data. Crashes if not found or malformed.
pub fn load_oracle_price(
  reference_inputs: List<Input>,
  oracle_nft_policy_id: PolicyId,
) -> OraclePrice {
  expect Some(oracle_input) =
    list.find(
      reference_inputs,
      fn(input) {
        assets.quantity_of(input.output.value, oracle_nft_policy_id, oracle_nft_name) == 1
      },
    )

  expect InlineDatum(raw_datum) = oracle_input.output.datum
  expect AggState(price_data): Charli3OracleDatum = raw_datum
  expect GenericData { price_map } = price_data

  expect Some(price) = pairs.get_first(price_map, price_key)
  expect Some(creation_time) = pairs.get_first(price_map, creation_time_key)
  expect Some(expiration_time) = pairs.get_first(price_map, expiration_key)

  expect price > 0

  OraclePrice { price, creation_time, expiration_time }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Validate that the oracle price has not expired and is within the
/// optional user-defined age limit.
pub fn validate_oracle_freshness(
  oracle: OraclePrice,
  validity_range: ValidityRange,
  max_price_age_ms: Option<Int>,
) -> Bool {
  expect Finite(tx_earliest_time) = validity_range.lower_bound.bound_type

  let not_expired = oracle.expiration_time > tx_earliest_time

  let within_age_limit =
    when max_price_age_ms is {
      None -> True
      Some(max_age) -> tx_earliest_time - oracle.creation_time <= max_age
    }

  and {
    not_expired?,
    within_age_limit?,
  }
}

/// Optional slippage guard: reject if price is outside user-defined bounds.
pub fn validate_price_bounds(
  price: Int,
  min_price: Option<Int>,
  max_price: Option<Int>,
) -> Bool {
  let above_min =
    when min_price is {
      None -> True
      Some(min) -> price >= min
    }
  let below_max =
    when max_price is {
      None -> True
      Some(max) -> price <= max
    }
  and {
    above_min?,
    below_max?,
  }
}

// ---------------------------------------------------------------------------
// Price computation
// ---------------------------------------------------------------------------

/// Compute how many units of the payment asset to send.
///
/// Both target_amount and oracle_price are scaled by 1e6.
/// Payment assets have 6 decimal places (lovelace, USDM, etc.).
///
/// Formula: payment_units = ceil(target_amount * 1_000_000 / oracle_price)
///
/// Example: $100 worth of ADA at ADA/USD = 400_000 ($0.40):
///   ceil(100_000_000 * 1_000_000 / 400_000) = 250_000_000 (250 ADA) ✓
pub fn compute_oracle_payment_amount(
  target_amount: Int,
  oracle_price: Int,
) -> Int {
  ceil_div(target_amount * 1_000_000, oracle_price)
}

/// Integer ceiling division for positive a and b.
pub fn ceil_div(a: Int, b: Int) -> Int {
  ( a + b - 1 ) / b
}
