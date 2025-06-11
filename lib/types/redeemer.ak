use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference}

// Identification Redeemer type
pub type Action {
  Mint
  Burn
}

pub type ProjectValidationRedeemer {
  action: Int,
  amount: Int,
  oref: OutputReference,
}

// Marketplace Redeemer type
pub type MarketplaceRedeemer {
  Buy
  Withdraw
}

/// CET redemeer type
pub type EmissionBurnRedeemer {
  cot_policyid: PolicyId,
}
