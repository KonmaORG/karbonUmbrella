//// this module  holds 2 contract one for project initiating and one for project validation

use aiken/collection/dict
use cardano/address.{Script}
use cardano/addresses
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, find_input,
}
use cardano/tx
use cardano/value
use constants
use functions/utils
use types/datum.{ProjectDatum}
use types/redeemer.{ProjectValidationRedeemer}
use types/token.{Token}
use validation/find
use validation/payout

/// this contract implements the multisig validator logic
/// where multiple validator will need to sign the tx to approve or reject the project
/// also mints carbon token
validator project_validation(
  config_nft: PolicyId,
  validator_contract_mint: PolicyId,
) {
  spend(
    datum: Option<ProjectDatum>,
    redeemer: ProjectValidationRedeemer,
    oref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum
    let Transaction {
      mint,
      inputs,
      reference_inputs,
      extra_signatories,
      outputs,
      ..
    } = tx
    expect Some(script_input) = find_input(inputs, oref)
    expect Script(script_hash) = script_input.output.address.payment_credential
    let ref_datum =
      utils.ref_datum_by_nft(
        reference_inputs,
        config_nft,
        constants.identication_tkn,
      )

    // expect must_burn_less_than_0(mint, validator_contract_mint)
    // expect
    //   atleast_signedby(extra_signatories, ref_datum.multisig_validator_group)
    when redeemer.action is {
      // 0 -> Accept
      0 -> {
        let developer_addr =
          addresses.create_address(datum.developer.1st, datum.developer.2nd)
        let tkname = utils.token_name_oref(oref)
        let value =
          value.from_token(
            Token { pid: script_hash, tkn: tkname, amt: redeemer.amount },
          )
        payout.exact(developer_addr, value, outputs)?
      }
      // 1 -> Reject
      1 -> and {
          utils.must_burn_less_than_0(mint, validator_contract_mint),
          tx.verify_multisig(
            extra_signatories,
            ref_datum.multisig_validator_group.signers,
            ref_datum.multisig_validator_group.required,
          ),
        }
      _ -> fail
    }
  }

  mint(
    redeemer: ProjectValidationRedeemer,
    policy_id: PolicyId,
    tx: Transaction,
  ) {
    let Transaction { inputs, mint, reference_inputs, extra_signatories, .. } =
      tx
    let ref_datum =
      utils.ref_datum_by_nft(
        reference_inputs,
        config_nft,
        constants.identication_tkn,
      )

    when redeemer.action is {
      0 -> {
        expect Some(oref_input) = find_input(inputs, redeemer.oref)
        expect InlineDatum(oref_input_datum) = oref_input.output.datum
        expect _: ProjectDatum = oref_input_datum
        let tkname = utils.token_name_oref(redeemer.oref)
        and {
          utils.must_burn_less_than_0(mint, validator_contract_mint),
          value.prove_exact_nft(mint, policy_id, tkname),
          tx.verify_multisig(
            extra_signatories,
            ref_datum.multisig_validator_group.signers,
            ref_datum.multisig_validator_group.required,
          ),
        }
      }
      1 -> {
        let multi_sig =
          tx.verify_multisig(
            extra_signatories,
            ref_datum.multisig_validator_group.signers,
            ref_datum.multisig_validator_group.required,
          )
        if multi_sig {
          utils.must_burn_less_than_0(mint, policy_id)
        } else {
          expect [Pair(_, cet_qty)] =
            mint |> assets.tokens(ref_datum.cet_policyid) |> dict.to_pairs
          expect [Pair(_, cot_qty)] =
            mint |> assets.tokens(policy_id) |> dict.to_pairs
          and {
            cet_qty < 0,
            cot_qty == cet_qty,
          }
        }
      }
      _ -> fail
    }
  }

  else(_) {
    fail
  }
}

/// this contract mints the project_nft and send it to project_validation contract
/// 
validator project_initiator(config_nft: PolicyId) {
  mint(redeemer: Int, policy_id: PolicyId, tx: Transaction) {
    let Transaction { mint, reference_inputs, outputs, .. } = tx
    when redeemer is {
      0 -> {
        let ref_datum =
          utils.ref_datum_by_nft(
            reference_inputs,
            config_nft,
            constants.identication_tkn,
          )
        let payout_addr = addresses.create_address(ref_datum.fees_address, "")
        let project_validation_addr =
          addresses.create_address(ref_datum.spend_address, "")
        let project_validation_output =
          find.output_by_addr(outputs, project_validation_addr)
        // got error while doing this
        // output.address == from_verification_key(ref_datum.spend_address)
        expect InlineDatum(script_data) = project_validation_output.datum
        expect project_validation_datum: ProjectDatum = script_data
        let payout_value =
          value.from_token(
            Token {
              pid: ref_datum.fees_asset_class.policy_id,
              tkn: ref_datum.fees_asset_class.asset_name,
              amt: ref_datum.fees_amount,
            },
          )
        and {
          utils.is_category_from_supported_categories(
            ref_datum.categories,
            project_validation_datum.category,
          )?,
          value.prove_exact_nft(
            mint,
            policy_id,
            project_validation_datum.asset_name,
          )?,
          payout.exact(payout_addr, payout_value, outputs),
          utils.must_send_nft_and_datum_to_script(
            project_validation_output,
            policy_id,
          )?,
        }
      }
      1 -> utils.must_burn_less_than_0(mint, policy_id)

      _ -> fail
    }
  }

  else(_) {
    fail
  }
}
