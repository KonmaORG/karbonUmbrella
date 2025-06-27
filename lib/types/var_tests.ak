use aiken/cbor.{serialise}
use types/datum.{GovernanceDatum}
use types/moment.{Moment}
use types/redeemer.{
  ExecuteProposal, GovernanceRedeemer, RejectProposal, SubmitProposal,
  VoteProposal,
}
use types/utils.{
  FeeAddressUpdate, FeeAmountUpdate, InProgress, Pending, VotesCount,
  VotesStruct, Yes,
}
use types/wallet.{Wallet}

// NOTE: The definitions for `Wallet` and `Moment` types were not found in the
// project. Therefore, tests for `GovernanceDatum` and the `FeeAddressUpdate`
// variant of `ProposalAction` cannot be written.
// Please provide the definitions for `lib/types/wallet.ak` and
// `lib/types/moment.ak` to enable complete testing.
const proposalid = "1"

const pkh1_hex = #"a0a1a2a3a4a5a6a7a8a9b0b1b2b3b4b5b6b7b8b9c0c1c2c3d0d1d2d3"

const pkh2_hex = #"e0e1e2e3e4e5e6e7e8e9f0f1f2f3f4f5f6f7f8f9a0a1a2a3b0b1b2b3"

const datum_var =
  GovernanceDatum {
    proposal_id: proposalid,
    submitted_by: pkh1_hex,
    proposal_action: FeeAmountUpdate(1000),
    votes: [
      VotesStruct { voter: pkh2_hex, vote: Pending },
      VotesStruct { voter: pkh1_hex, vote: Pending },
    ],
    votes_count: VotesCount { yes: 0, no: 0, abstain: 0 },
    deadline: Moment { start: 0, end: 0 },
    proposal_state: InProgress,
  }

const feeaddress = FeeAddressUpdate(Wallet { pkh: pkh1_hex, sc: pkh2_hex })

const submit_proposal: GovernanceRedeemer =
  SubmitProposal { proposal_id: proposalid }

const vote_proposal: GovernanceRedeemer =
  VoteProposal { proposal_id: proposalid, voter: pkh2_hex, vote: Yes }

const execute_proposal: GovernanceRedeemer =
  ExecuteProposal { proposal_id: proposalid }

const reject_proposal: GovernanceRedeemer =
  RejectProposal { proposal_id: proposalid }

test datum() {
  // proposal_id matched with offchain cbor
  trace @"proposal_id": serialise(datum_var.proposal_id)
  // submitted_by matched with offchain cbor
  trace @"submited_by": serialise(datum_var.submitted_by)
  // proposal_action matched with offchain cbor
  trace @"proposal_action": serialise(datum_var.proposal_action)
  // ------------------------------
  trace @"votes": serialise(datum_var.votes)
  // votes_count matched with offchain cbor 
  trace @"votes_count": serialise(datum_var.votes_count)
  // deadline matched with offchain cbor 
  trace @"deadline": serialise(datum_var.deadline)
  // proposal_state matched with offchain cbor 
  trace @"proposal_state": serialise(datum_var.proposal_state)
  trace @"Pending": serialise(Pending)
  trace @"-------------------REDEEMER-------------------"
  // Redeemers matched with offchain cbor
  trace @"submit_proposal": serialise(submit_proposal)
  trace @"vote_proposal": serialise(vote_proposal)
  trace @"execute_proposal": serialise(execute_proposal)
  trace @"reject_proposal": serialise(reject_proposal)
  // -----ENTIRE DATUM AS CBOR-----
  trace @"------------------DATUM AS CBOR-----------------"
  trace @"datum_var": serialise(datum_var)
  trace @"feeAddress": serialise(feeaddress)
  True
}
