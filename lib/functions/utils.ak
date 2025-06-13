use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/addresses
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/value
use constants
use types/datum.{
  BackerDatum, CampaignDatum, CampaignState, ConfigDatum, ProjectDatum,
}
use types/token.{Token}
use types/utils.{AddressTuple, PaymentKeyHash, StakeKeyHash}
use validation/payout

///   "validation/payout"  from logical mechanism
pub fn is_category_from_supported_categories(
  categories: List<ByteArray>,
  category: ByteArray,
) -> Bool {
  list.has(categories, category)
}

pub fn must_send_nft_and_datum_to_script(output: Output, policy_id: PolicyId) {
  expect InlineDatum(output_datum) = output.datum
  expect _: ProjectDatum = output_datum
  list.has(output.value |> assets.policies, policy_id)?
}

pub fn must_burn_less_than_0(mint: Value, policy_id: PolicyId) -> Bool {
  let values: Pairs<AssetName, Int> =
    mint
      |> assets.tokens(policy_id)
      |> dict.to_pairs()

  list.all(values, fn(Pair(_, amount)) { amount < 0 })?
}

pub fn ref_datum_by_nft(
  inputs: List<Input>,
  pid: PolicyId,
  tkn: AssetName,
) -> ConfigDatum {
  let datum_data = input_datum_by_nft(inputs, pid, tkn)
  if datum_data is datum: ConfigDatum {
    datum
  } else {
    fail @"Datum Type did not Match ConfigDatum On Input"
  }
}

pub fn script_address_check(
  outputs: List<Output>,
  policy_id: PolicyId,
  token_name: ByteArray,
  redeemer: AddressTuple,
) {
  expect Some(output) =
    list.find(
      outputs,
      fn(o) { assets.quantity_of(o.value, policy_id, token_name) == 1 },
    )
  let address_data: Data = redeemer
  expect InlineDatum(address_datum) = output.datum
  and {
    output.address == script_address_from_tuple(redeemer),
    (address_datum == address_data)?,
  }
}

pub fn input_datum_by_nft(
  inputs: List<Input>,
  pid: PolicyId,
  tkn: AssetName,
) -> Data {
  when inputs is {
    [input, ..rest] ->
      if value.prove_exact_nft(input.output.value, pid, tkn) {
        when input.output.datum is {
          // inline and holding the nft
          InlineDatum(inbound_datum) -> inbound_datum
          _ -> fail @"No Datum On Input"
        }
      } else {
        input_datum_by_nft(rest, pid, tkn)
      }
    [] -> fail @"No Datum Found In inputs"
  }
}

pub fn outputs_by_pid(
  outputs: List<Output>,
  pid: PolicyId,
  tkn: ByteArray,
) -> List<Output> {
  let output =
    when outputs is {
      [output, ..rest] ->
        if value.prove_exact_nft(output.value, pid, tkn) {
          [output, ..outputs_by_pid(rest, pid, tkn)]
        } else {
          outputs_by_pid(rest, pid, tkn)
        }
      [] -> []
    }
  output
}

pub fn outputs_by_addr(outputs: List<Output>, addr: Address) -> List<Output> {
  let output =
    when outputs is {
      [output, ..rest] ->
        if output.address == addr {
          [output, ..outputs_by_addr(rest, addr)]
        } else {
          outputs_by_addr(rest, addr)
        }
      [] -> []
    }
  output
}

fn do_total_token_amount(
  inputs: List<Input>,
  cet_pid: PolicyId,
  cot_pid: PolicyId,
  cet_tkn: ByteArray,
  cot_tkn: ByteArray,
  cet_qty: Int,
  cot_qty: Int,
) {
  when inputs is {
    [input, ..rest] -> {
      let cet_amt: Int =
        assets.quantity_of(input.output.value, cet_pid, cet_tkn)
      let cot_amt: Int =
        assets.quantity_of(input.output.value, cot_pid, cot_tkn)
      do_total_token_amount(
        rest,
        cet_pid,
        cot_pid,
        cet_tkn,
        cot_tkn,
        cet_qty + cet_amt,
        cot_qty + cot_amt,
      )
    }
    [] -> (cet_qty, cot_qty)
  }
}

pub fn get_output_addr(script: PolicyId, inputs: List<Input>) {
  expect Some(input) = list.head(inputs)
  when input.output.address.stake_credential is {
    Some(Inline(VerificationKey(skh))) ->
      address.from_script(script)
        |> address.with_delegation_key(skh)
    _ -> fail @"Input Stake Componenet Missing"
  }
}

pub fn token_name_oref(oref: OutputReference) {
  let hashed = oref |> cbor.serialise |> crypto.blake2b_224
  hashed
}

pub fn calculate_payout_royalty(amount: Int) {
  // royalty is constant
  let marketplace = amount * constants.royalty_amt / 100
  let seller = amount - marketplace
  let marketplace_payout =
    value.from_token(Token { pid: "", tkn: "", amt: marketplace })
  let seller_payout = value.from_token(Token { pid: "", tkn: "", amt: seller })
  (marketplace_payout, seller_payout)
}

pub fn user_script_address(inputs: List<Input>, outputs: List<Output>) {
  expect Some(input) = list.head(inputs)
  expect Some(Inline(VerificationKey(skh))) =
    input.output.address.stake_credential
  expect Some(output) = list.head(outputs)
  when (output.address.payment_credential, output.address.stake_credential) is {
    (Script(_), Some(Inline(VerificationKey(o_sk)))) ->
      if skh == o_sk {
        output
      } else {
        fail @"Incorrect Stake Component"
      }
    _ -> fail @"Incorrect Tokens Output Address"
  }
}

pub fn script_address_from_tuple(key_hash_tuple: (PaymentKeyHash, StakeKeyHash)) {
  let (pkh, skh) = key_hash_tuple
  Address {
    payment_credential: pkh |> Script,
    stake_credential: if skh == "" {
      None
    } else {
      skh |> Script |> Inline |> Some
    },
  }
}

pub fn find_ref_input(inputs: List<Input>, policy_id: PolicyId) {
  expect Some(input) =
    list.find(
      inputs,
      fn(i) { list.has(i.output.value |> assets.policies, policy_id) },
    )
  input
}

pub fn must_have_one_output_with_policy(
  outputs: List<Output>,
  policy_id: PolicyId,
  address: Address,
) {
  list.count(
    outputs,
    fn(o) {
      and {
        list.has(o.value |> assets.policies, policy_id)?,
        (o.address == address)?,
      }
    },
  ) == 1
}

pub fn must_send_remaining_token_to_addr(
  tx: Transaction,
  cet_pid: PolicyId,
  cot_pid: PolicyId,
  cet_tkn: ByteArray,
  cot_tkn: ByteArray,
  burn_qty: Int,
  user_script: Address,
) {
  // let value = concat_inputs_value(inputs, assets.zero)
  let (cet_qty, cot_qty) =
    do_total_token_amount(tx.inputs, cet_pid, cot_pid, cet_tkn, cot_tkn, 0, 0)

  let o_cet = cet_qty + burn_qty
  let o_cot = cot_qty + burn_qty

  if o_cet == 0 && o_cot == 0 {
    True
  } else {
    let expected_output =
      value.from_tokens(
        [
          Token { pid: cet_pid, tkn: cet_tkn, amt: o_cet },
          //burn_qty is negative value
          Token { pid: cot_pid, tkn: cot_tkn, amt: o_cot },
        ],
      )
    payout.at_least(user_script, expected_output, tx.outputs)?
  }
}

pub fn campaign_state(datum: CampaignDatum, state: CampaignState) -> Bool {
  // must consume/refer state token UTxO
  datum.state == state
}

pub fn must_refund(
  tx: Transaction,
  script_address: Address,
  backer_datum: BackerDatum,
) {
  let backer_datum_data: Data = backer_datum
  let backer_address: Address = addresses.from_wallet(backer_datum)

  // collect input backer support lovelaces from self address
  let sum_input =
    fn(sum, Input { output: Output { address, datum, value, .. }, .. }) {
      if address == script_address {
        when datum is {
          InlineDatum(input_datum) ->
            if input_datum == backer_datum_data {
              assets.lovelace_of(value) + sum
            } else {
              sum
            }
          _ -> sum
        }
      } else {
        sum
      }
    }
  let input_lovelace = list.reduce(tx.inputs, 0, sum_input)

  // collect output lovelaces to backer address
  let sum_output =
    fn(sum, Output { address, value, .. }) {
      if address == backer_address {
        assets.lovelace_of(value) + sum
      } else {
        sum
      }
    }
  let output_lovelace = list.reduce(tx.outputs, 0, sum_output)

  output_lovelace >= input_lovelace
}
