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
