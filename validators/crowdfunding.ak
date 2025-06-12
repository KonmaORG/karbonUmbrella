use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address, Script}
use cardano/addresses
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/value
use constants
use functions/utils
use types/datum.{
  CampaignDatum, Cancelled, ConfigDatum, Finished, Initiated, Released, Running,
}
use types/moment.{Moment}
use types/redeemer.{CampaignAction, Cancel, Finish, Refund, Release, Support}
use types/token.{Token}
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
          let CampaignDatum { name, goal, fraction, .. } = campaign_datum
          let fraction_amount = goal / fraction

          // START HERE
          expect [backer_reward_token,
            script_reward_token] =
            utils.outputs_by_pid(tx.outputs, self_script, name)
          let (backer_amount, script_token) =
            utils.outputs_by_addr(outputs, self_script, name)
          validate_support_campaign(
            tx,
            self_script,
            datum: CampaignDatum { ..campaign_datum, state: Running },
          )
        } else {
          fail @"Invalid Cancel Datum Type! Must be CampaignDatum"
        }
      // Cancel campaign:
      (Some(current_datum), Cancel) ->
        if current_datum is campaign_datum: CampaignDatum {
          validate_cancel_campaign(
            tx,
            self_script,
            campaign_datum,
            multisig_validator_group,
            utils.script_address_from_tuple(state_token_script),
          )
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
