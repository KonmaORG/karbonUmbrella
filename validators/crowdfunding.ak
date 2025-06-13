use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, Script}
use cardano/addresses
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/tx
use cardano/value
use constants
use functions/utils
use types/datum.{
  BackerDatum, CampaignDatum, Cancelled, ConfigDatum, Finished, Initiated,
  Released, Running,
}
use types/moment.{Moment}
use types/redeemer.{CampaignAction, Cancel, Finish, Refund, Release, Support}
use types/token.{Token}
use validation/find
use validation/payout

validator campaign(config_nft: PolicyId) {
  mint(
    redeemer campaign_datum: CampaignDatum,
    policy_id self_script: PolicyId,
    tx: Transaction,
  ) {
    when campaign_datum.state is {
      Finished | Cancelled ->
        assets.quantity_of(tx.mint, self_script, campaign_datum.name) <= 0
      _ -> {
        expect CampaignDatum {
          goal,
          name,
          deadline,
          milestone,
          creator,
          fraction,
          state: Initiated,
        } = campaign_datum
        expect goal > 0
        let script_addr = addresses.create_address(self_script, creator.sc)
        let payout_value =
          value.from_token(Token { pid: self_script, tkn: name, amt: fraction })
        and {
          // making sure the deadline is of future
          moment.is_before(
            Moment { start: 0, end: deadline },
            tx.validity_range,
          ),
          // making sure the milestone[] is set to false, it will be true after payout release for each milestone
          !list.has(milestone, True),
          // checking that the rewward token is of `fraction` quantity
          assets.quantity_of(tx.mint, self_script, name) == fraction,
          // the reward token must be send to the `script`+`userStakeAddress`
          payout.exact(script_addr, payout_value, tx.outputs),
        }
      }
    }
  }

  spend(
    datum: Option<Data>,
    redeemer: CampaignAction,
    o_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(Input { output: Output { address, .. }, .. }) =
      transaction.find_input(tx.inputs, o_ref)
    expect Script(self_script) = address.payment_credential
    let ConfigDatum { multisig_validator_group, fees_address, .. } =
      utils.ref_datum_by_nft(
        tx.reference_inputs,
        config_nft,
        constants.identication_tkn,
      )
    when (datum, redeemer) is {
      // Support campaign:
      (Some(current_datum), Support) ->
        if current_datum is campaign_datum: CampaignDatum {
          let CampaignDatum { name, goal, fraction, creator, .. } =
            campaign_datum
          let fraction_amount = goal / fraction

          expect [backer_reward_output,
            script_reward_output] =
            utils.outputs_by_pid(tx.outputs, self_script, name)
          expect [backer_amount_output,
            script_token_output] =
            utils.outputs_by_addr(
              tx.outputs,
              addresses.create_address(self_script, creator.sc),
            )
          let backer_reward_qty =
            assets.quantity_of(backer_reward_output.value, self_script, name)
          let script_reward_qty =
            assets.quantity_of(script_reward_output.value, self_script, name)

          let backer_lovelace_qty =
            assets.lovelace_of(backer_amount_output.value)
          let script_reward_qty_ =
            assets.quantity_of(script_token_output.value, self_script, name)
          expect InlineDatum(output_datum) = script_token_output.datum
          and {
            output_datum == current_datum,
            utils.is_running_campaign(campaign_datum),
            script_reward_qty == script_reward_qty_,
            backer_lovelace_qty / fraction_amount == backer_reward_qty,
          }
        } else {
          fail @"Invalid Support Datum Type! Must be CampaignDatum"
        }
      // Cancel campaign:
      (Some(current_datum), Cancel) ->
        if current_datum is campaign_datum: CampaignDatum {
          let CampaignDatum { creator, deadline, .. } = campaign_datum
          let is_signed_by_platform =
            tx.verify_multisig(
              tx.extra_signatories,
              multisig_validator_group.signers,
              multisig_validator_group.required,
            )
          let output_datum_data =
            find.output_datum_by_addr(
              tx.outputs,
              addresses.create_address(self_script, creator.sc),
            )
          expect expected_datum_data: Data =
            CampaignDatum { ..campaign_datum, state: Cancelled }
          and {
            if is_signed_by_platform? {
              moment.is_after(
                Moment { start: 0, end: deadline },
                tx.validity_range,
              )
            } else {
              // must be signed by creator
              list.has(tx.extra_signatories, creator.pkh)
            },
            utils.is_running_campaign(campaign_datum),
            (output_datum_data == expected_datum_data)?,
          }
        } else if current_datum is backer_datum: BackerDatum {
          tx |> validate_refund_support(self_script, backer_datum)
        } else {
          fail @"Invalid Cancel Datum Type! Must be CampaignDatum"
        }

      // Finish campaign:
      (Some(current_datum), Finish) ->
        validate_finish_campaign(
          tx,
          self_script,
          current_datum,
          utils.script_address_from_tuple(state_token_script),
          multisig_validator_group,
        )
      // Refund campaign:
      (Some(current_datum), Refund) ->
        if current_datum is backer_datum: BackerDatum {
          tx |> validate_refund_support(self_script, backer_datum)
        } else {
          fail @"Invalid Refund Datum Type! Must be BackerDatum"
        }
      // Release Payment
      (Some(current_datum), Release) ->
        if current_datum is campaign_datum: CampaignDatum {
          validate_release_campaign(
            tx,
            self_script,
            campaign_datum,
            fees_address,
            utils.script_address_from_tuple(state_token_script),
            multisig_validator_group,
          )
        } else {
          fail @"Invalid Refund Datum Type! Must be BackerDatum"
        }
      // NoDatum etc:
      _ -> {
        expect !utils.is_running_campaign(tx.reference_inputs, self_script)
        utils.atleast_signedby(tx.extra_signatories, multisig_validator_group)
      }
    }
  }

  else(_) {
    fail
  }
}
