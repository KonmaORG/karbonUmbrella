use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{PolicyId}
use types/utils.{AssetClass, Multisig}

pub type ConfigDatum {
  fees_address: VerificationKeyHash,
  fees_amount: Int,
  fees_asset_class: AssetClass,
  spend_address: VerificationKeyHash,
  categories: List<ByteArray>,
  multisig_validator_group: Multisig,
  multisig_refutxoupdate: Multisig,
  cet_policyid: PolicyId,
  cot_policyid: PolicyId,
}
