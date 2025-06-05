use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use cardano/value
use types/datum.{ConfigDatum, ProjectDatum}

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

pub fn token_name_oref(oref: OutputReference) {
  let hashed = oref |> cbor.serialise |> crypto.blake2b_224
  hashed
}
