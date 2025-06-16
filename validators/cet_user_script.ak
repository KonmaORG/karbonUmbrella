// This module defines a validator that manages user-specific script addresses for holding
// Carbon Emission Tokens (CET).

use aiken/collection/dict
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction, find_input}
use functions/utils

/// This validator manages a user-specific script address for holding CETs.
/// The address is unique to each user, derived from their stake credentials.
/// This design ensures that CETs are locked in a user-specific contract and cannot be transferred,
/// while allowing the user to spend their Carbon Offsetting Tokens (COT).
validator user_script(cet_policyid: PolicyId, cot_policyid: PolicyId) {
  spend(_datum, redeemer: Int, oref: OutputReference, tx: Transaction) {
    let Transaction { inputs, mint, .. } = tx
    expect Some(self_input) = find_input(inputs, oref)
    expect Script(script) = self_input.output.address.payment_credential
    let user_script_address = utils.get_output_addr(script, inputs)
    when redeemer is {
      // Action 0: Offset emissions by burning CET and COT.
      0 -> {
        expect [Pair(cet_tkn, cet_qty)] =
          mint |> assets.tokens(cet_policyid) |> dict.to_pairs
        expect [Pair(cot_tkn, cot_qty)] =
          mint |> assets.tokens(cot_policyid) |> dict.to_pairs

        and {
          // Ensure the quantity of CETs being burned is negative.
          (cet_qty < 0)?,
          // The quantity of burned CETs must equal the quantity of burned COTs.
          (cet_qty == cot_qty)?,
          // Ensure any remaining tokens are sent back to the user's script address.
          utils.must_send_remaining_token_to_addr(
            tx,
            cet_policyid,
            cot_policyid,
            cet_tkn,
            cot_tkn,
            cot_qty,
            user_script_address,
          )?,
        }
      }
      // Action 1: Withdraw COT or other tokens.
      // This action allows the user to spend tokens from the script address
      1 -> fail @"not yet implemented"
      _ -> fail @"invalid redeemer value"
    }
  }

  else(_) {
    fail
  }
}
