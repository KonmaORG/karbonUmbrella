use aiken/collection/dict.{from_pairs}
use aiken/collection/pairs
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
} as tx
use cardano/value
use constants
use types/datum.{ConfigDatum, GovernanceDatum}
use types/moment.{Moment}
use types/redeemer.{
  ExecuteProposal, RejectProposal, SubmitProposal, VoteProposal,
}
use types/token.{Token}
use types/utils.{
  AssetClass, Executed, InProgess, Multisig, No, Pending, Rejected, ValidatorAdd,
  VotesCount, Yes,
}
use types/wallet.{Wallet}

// use validators/dao

// Mock Data
fn mock_policy_id() -> PolicyId {
  "d8b085a40a3301673c489529354b73513919bd059c197f19a97499ab"
}

fn mock_stake_hash() -> ByteArray {
  "a0f87da4242a404885013532a73a1a491199c8435c3435b9b3a55272"
}

fn mock_voter() -> ByteArray {
  "b0c8ddd8f4282e2a085a4107dcf7c9e1d7a4f464f7a7f0f8f8b2f2e2"
}

fn mock_script_address(self_script: PolicyId) -> Address {
  Address {
    payment_credential: Script(self_script),
    stake_credential: Some(Inline(VerificationKey(mock_stake_hash()))),
  }
}

test mint_initial_proposal() {
  let self_script = mock_policy_id()
  let proposal_id = "Test Proposal"

  let governance_datum =
    GovernanceDatum {
      proposal_id,
      submitted_by: mock_voter(),
      proposal_action: ValidatorAdd(mock_voter()),
      votes: dict.empty,
      votes_count: VotesCount { yes: 0, no: 0, abstain: 0 },
      deadline: Moment { start: 0, end: 1735689600000 },
      // 2025-01-01
      proposal_state: InProgess,
    }

  let outputs =
    [
      Output {
        address: mock_script_address(self_script),
        value: value.from_token(
          Token {
            pid: self_script,
            tkn: string.to_bytearray(proposal_id),
            amt: 1,
          },
        ),
        datum: InlineDatum(governance_datum),
        reference_script: None,
      },
    ]

  let tx = Transaction { inputs , ..tx.placeholder }

  // Transaction {
  //   outputs: outputs,
  //   mint: value.from_token(
  //     Token {
  //       pid: self_script,
  //       tkn: string.to_bytearray(proposal_id),
  //       amt: 1,
  //     },
  //   ),
  //   certificates: [],
  //   validity_range: time.interval_from(time.from_posix(1672531200000)),
  //   // 2023-01-01
  //   fee: 100000,
  //   extra_signatories: [mock_voter()],
  //   ..tx.placeholder
  // }
  dao(mock_policy_id()).mint(
    SubmitProposal { proposal_id: string.to_bytearray(proposal_id) },
    self_script,
    tx,
  )
}

test spend_vote_proposal() {
  let self_script = mock_policy_id()
  let proposal_id = "Test Proposal"
  let voter = mock_voter()

  let initial_datum =
    GovernanceDatum {
      proposal_id: string.to_bytearray(proposal_id),
      submitted_by: voter,
      proposal_action: ValidatorAdd(voter),
      votes: from_pairs([Pair(voter, Pending)]),
      votes_count: VotesCount { yes: 0, no: 0, abstain: 0 },
      deadline: moment.from_posix(1735689600000),
      // 2025-01-01
      proposal_state: InProgess,
    }

  let updated_datum =
    GovernanceDatum {
      ..initial_datum,
      votes: from_pairs([Pair(voter, Yes)]),
      votes_count: VotesCount { yes: 1, no: 0, abstain: 0 },
    }

  let input_utxo =
    Output {
      address: mock_script_address(self_script),
      value: value.from_token(
        Token {
          pid: self_script,
          tkn: string.to_bytearray(proposal_id),
          amt: 1,
        },
      ),
      datum: InlineDatum(initial_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [Input { output: input_utxo, reference: None }],
      reference_inputs: [],
      outputs: [
        Output {
          address: mock_script_address(self_script),
          value: value.from_token(
            Token {
              pid: self_script,
              tkn: string.to_bytearray(proposal_id),
              amt: 1,
            },
          ),
          datum: InlineDatum(updated_datum),
          reference_script: None,
        },
      ],
      withdrawals: [],
      mint: value.zero(),
      certificates: [],
      validity_range: time.interval_from(time.from_posix(1672531200000)),
      // 2023-01-01
      fee: 100000,
      extra_signatories: [],
      collateral: None,
      required_signatories: [],
      network: 0,
      metadata: None,
    }

  dao(mock_policy_id()).spend(
    Some(initial_datum),
    VoteProposal {
      proposal_id: string.to_bytearray(proposal_id),
      voter,
      vote: Yes,
    },
    OutputReference { transaction_id: "", index: 0 },
    tx,
  )
}

test spend_execute_proposal() {
  let self_script = mock_policy_id()
  let proposal_id = "Test Proposal"
  let voter = mock_voter()

  let initial_datum =
    GovernanceDatum {
      proposal_id: string.to_bytearray(proposal_id),
      submitted_by: voter,
      proposal_action: ValidatorAdd(voter),
      votes: from_pairs([Pair(voter, Yes)]),
      votes_count: VotesCount { yes: 1, no: 0, abstain: 0 },
      deadline: moment.from_posix(1672531200000),
      // 2023-01-01
      proposal_state: InProgess,
    }

  let updated_datum =
    GovernanceDatum { ..initial_datum, proposal_state: Executed }

  let config_nft = "c0nfig_nft_p0licy"

  let initial_config_datum =
    ConfigDatum {
      fees_address: Wallet { pkh: "", sc: "" },
      fees_amount: 0,
      fees_asset_class: AssetClass { policy_id: "", asset_name: "" },
      spend_address: Wallet { pkh: "", sc: "" },
      categories: [],
      multisig_validator_group: Multisig { required: 1, signers: [] },
      multisig_refutxoupdate: Multisig { required: 1, signers: [] },
      cet_policyid: "",
      cot_policyid: "",
      dao_policyid: self_script,
    }

  let updated_config_datum =
    ConfigDatum {
      ..initial_config_datum,
      multisig_validator_group: Multisig { required: 1, signers: [voter] },
    }

  let input_utxo =
    Output {
      address: mock_script_address(self_script),
      value: value.from_token(
        Token {
          pid: self_script,
          tkn: string.to_bytearray(proposal_id),
          amt: 1,
        },
      ),
      datum: InlineDatum(initial_datum),
      reference_script: None,
    }

  let config_input =
    Output {
      address: mock_script_address(self_script),
      value: value.from_token(
        Token { pid: config_nft, tkn: constants.identication_tkn, amt: 1 },
      ),
      datum: InlineDatum(initial_config_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [
        Input { output: input_utxo, reference: None },
        Input { output: config_input, reference: None },
      ],
      reference_inputs: [],
      outputs: [
        Output {
          address: mock_script_address(self_script),
          value: value.from_token(
            Token {
              pid: self_script,
              tkn: string.to_bytearray(proposal_id),
              amt: 1,
            },
          ),
          datum: InlineDatum(updated_datum),
          reference_script: None,
        },
        Output {
          address: mock_script_address(self_script),
          value: value.from_token(
            Token { pid: config_nft, tkn: constants.identication_tkn, amt: 1 },
          ),
          datum: InlineDatum(updated_config_datum),
          reference_script: None,
        },
      ],
      withdrawals: [],
      mint: value.zero(),
      certificates: [],
      validity_range: time.interval_from(time.from_posix(1735689600000)),
      // 2025-01-01
      fee: 100000,
      extra_signatories: [],
      collateral: None,
      required_signatories: [],
      network: 0,
      metadata: None,
    }

  dao(config_nft).spend(
    Some(initial_datum),
    ExecuteProposal { proposal_id: string.to_bytearray(proposal_id) },
    OutputReference { transaction_id: "", index: 0 },
    tx,
  )
}

test spend_reject_proposal() {
  let self_script = mock_policy_id()
  let proposal_id = "Test Proposal"
  let voter = mock_voter()

  let initial_datum =
    GovernanceDatum {
      proposal_id: string.to_bytearray(proposal_id),
      submitted_by: voter,
      proposal_action: ValidatorAdd(voter),
      votes: from_pairs([Pair(voter, No)]),
      votes_count: VotesCount { yes: 0, no: 1, abstain: 0 },
      deadline: moment.from_posix(1672531200000),
      // 2023-01-01
      proposal_state: InProgess,
    }

  let updated_datum =
    GovernanceDatum { ..initial_datum, proposal_state: Rejected }

  let input_utxo =
    Output {
      address: mock_script_address(self_script),
      value: value.from_token(
        Token {
          pid: self_script,
          tkn: string.to_bytearray(proposal_id),
          amt: 1,
        },
      ),
      datum: InlineDatum(initial_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [Input { output: input_utxo, reference: None }],
      reference_inputs: [],
      outputs: [
        Output {
          address: mock_script_address(self_script),
          value: value.from_token(
            Token {
              pid: self_script,
              tkn: string.to_bytearray(proposal_id),
              amt: 1,
            },
          ),
          datum: InlineDatum(updated_datum),
          reference_script: None,
        },
      ],
      withdrawals: [],
      mint: value.zero(),
      certificates: [],
      validity_range: time.interval_from(time.from_posix(1735689600000)),
      // 2025-01-01
      fee: 100000,
      extra_signatories: [],
      collateral: None,
      required_signatories: [],
      network: 0,
      metadata: None,
    }

  dao(mock_policy_id()).spend(
    Some(initial_datum),
    RejectProposal { proposal_id: string.to_bytearray(proposal_id) },
    OutputReference { transaction_id: "", index: 0 },
    tx,
  )
}
