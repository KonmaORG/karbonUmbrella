use cardano/assets.{PolicyId}
use types/utils.{AssetClass, Multisig}
use types/wallet.{Wallet}

pub type ConfigDatum {
  fees_address: Wallet,
  fees_amount: Int,
  fees_asset_class: AssetClass,
  spend_address: Wallet,
  categories: List<ByteArray>,
  multisig_validator_group: Multisig,
  multisig_refutxoupdate: Multisig,
  cet_policyid: PolicyId,
  cot_policyid: PolicyId,
}

pub type ProjectDatum {
  developer: Wallet,
  document: ByteArray,
  category: ByteArray,
  asset_name: ByteArray,
  fees_amount: Int,
  fees_asset_class: AssetClass,
}

pub type MarketplaceDatum {
  owner: Wallet,
  amount: Int,
}
