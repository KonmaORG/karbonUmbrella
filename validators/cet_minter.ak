//// this module handle's the buring and minting of the `CET`

use aiken/collection/dict
use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Transaction}
use functions/utils
use types/datum.{CETDatum}
use types/redeemer.{EmissionBurnRedeemer}

/// The `cet_minter` validator handles the minting and burning of Carbon Emission Tokens (CET).
/// It ensures that CETs are minted correctly based on emission data and can be burned
/// in a 1:1 ratio with Carbon Offset Tokens (COT).
validator cet_minter {
  mint(redeemer: Data, policy_id: PolicyId, tx: Transaction) {
    let Transaction { mint, inputs, outputs, .. } = tx

    // The validator's behavior depends on the type of redeemer provided.
    if redeemer is CETDatum {
      // This branch handles the minting of new CETs.
      let CETDatum { cet_qty, .. } = redeemer
      // Ensure that tokens are being minted under the correct policy.
      expect [Pair(token_name, qty)] =
        mint |> assets.tokens(policy_id) |> dict.to_pairs
      let cet_output = utils.user_script_address(inputs, outputs)
      expect InlineDatum(datum_data) = cet_output.datum
      let redeemer_data: Data = redeemer
      and {
        // The minted quantity must match the quantity specified in the redeemer.
        qty == cet_qty,
        // The same quantity of CETs must be sent to the user script address.
        assets.quantity_of(cet_output.value, policy_id, token_name) == qty,
        // The datum in the output must match the redeemer.
        datum_data == redeemer_data,
      }
    } else if redeemer is EmissionBurnRedeemer {
      // This branch handles the burning of CETs.
      expect [Pair(_, cet_qty)] =
        mint |> assets.tokens(policy_id) |> dict.to_pairs
      expect [Pair(_, cot_qty)] =
        mint |> assets.tokens(redeemer.cot_policyid) |> dict.to_pairs
      and {
        // The quantity of CETs being burned must be negative.
        cet_qty < 0,
        // The quantity of burned CETs must equal the quantity of burned COTs.
        cet_qty == cot_qty,
      }
    } else {
      fail @"invalid redeemer"
    }
  }

  else(_) {
    fail
  }
}
