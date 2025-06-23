use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference}
use types/utils.{Vote, Voter}

/// A redeemer for the `identification_nft` validator, specifying whether to mint or burn the NFT.
pub type Action {
  /// The action to mint the Identification NFT.
  Mint
  /// The action to burn the Identification NFT.
  Burn
}

/// A redeemer for the `project_validation` validator.
pub type ProjectValidationRedeemer {
  /// The action to perform: 0 for accepting a project, 1 for rejecting it.
  action: Int,
  /// The amount of Carbon Offsetting Tokens (COT) to be minted upon project approval.
  amount: Int,
  /// The output reference of the UTxO being spent.
  oref: OutputReference,
}

/// A redeemer for the `karbonstore` (marketplace) validator.
pub type MarketplaceRedeemer {
  /// The action to purchase an asset from the marketplace.
  Buy
  /// The action for the owner to withdraw their asset from the marketplace.
  Withdraw
}

/// A redeemer for the `cet_minter` validator, used when burning Carbon Emission Tokens (CET).
pub type EmissionBurnRedeemer {
  /// The policy ID of the Carbon Offsetting Tokens (COT) being burned alongside the CETs.
  cot_policyid: PolicyId,
}

/// A redeemer for the `campaign` validator, specifying the action to be taken on a crowdfunding campaign.
pub type CampaignAction {
  /// The action for a backer to contribute funds to a campaign.
  Support
  /// The action to cancel a campaign.
  Cancel
  /// The action to successfully finish a campaign.
  Finish
  /// The action for a backer to claim a refund from a cancelled campaign.
  Refund
  /// The action for the campaign creator to release milestone-based funds.
  Release
}

// -----DAO REDEEMER
/// A redeemer for the governance validator, specifying the action to be taken on a proposal.
pub type GovernanceRedeemer {
  /// The action to submit a new proposal.
  SubmitProposal { proposal_id: ByteArray }
  /// The action to vote on an existing proposal.
  VoteProposal { proposal_id: ByteArray, voter: Voter, vote: Vote }
  /// The action to execute an approved proposal.
  ExecuteProposal { proposal_id: ByteArray }
  /// The action to reject a proposal.
  RejectProposal { proposal_id: ByteArray }
}
