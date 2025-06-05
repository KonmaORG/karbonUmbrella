//// Identification Nft for finding the config Datum from reference Input.
//// most of the contracts will have this contracts policyId as parameter

use cardano/assets.{PolicyId}
use cardano/minting
use cardano/transaction.{OutputReference, Transaction}
use cardano/tx as logical_tx
use constants
use types/redeemer.{Action, Burn, Mint}

// from logical mechanism cardano/tx, cardano/minting

validator identification_nft(o_ref: OutputReference) {
  mint(redeemer: Action, policy_id: PolicyId, tx: Transaction) {
    let Transaction { inputs, mint, .. } = tx
    let flatten_value = assets.flatten(mint)
    when redeemer is {
      Mint -> and {
          logical_tx.is_spending_input(inputs, o_ref)?,
          minting.exact(flatten_value, policy_id, constants.identication_tkn, 1)?,
        }

      // must_mint_exactly_one(mint, policy_id)?,
      Burn ->
        minting.exact(flatten_value, policy_id, constants.identication_tkn, -1)
    }
  }

  else(_) {
    fail
  }
}
