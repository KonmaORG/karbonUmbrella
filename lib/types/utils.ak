use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{AssetName, PolicyId}

pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type PaymentKeyHash =
  VerificationKeyHash

pub type StakeKeyHash =
  VerificationKeyHash

pub type AddressTuple =
  (PaymentKeyHash, StakeKeyHash)

pub type Atleast =
  Int

pub type Multisig {
  required: Atleast,
  signers: List<VerificationKeyHash>,
}
