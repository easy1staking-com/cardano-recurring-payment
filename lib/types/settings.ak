use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{AssetName}

/// The name of the token that authenticates the settings UTXO
pub const settings_nft_name: AssetName = "settings"

pub type Settings {
  // BOT Payment PKH
  setting_admin_pkh: VerificationKeyHash,
  authorised_operators: List<VerificationKeyHash>,
  operator_fee_exempt_users: List<VerificationKeyHash>,
  operator_fee_lovelace: Int,
  base_fee_lovelace: Int,
}
