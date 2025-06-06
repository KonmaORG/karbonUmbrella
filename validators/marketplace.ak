use aiken/collection/list
use cardano/addresses
use cardano/transaction.{OutputReference, Transaction}
use constants
use functions/utils
use types/datum.{MarketplaceDatum}
use types/redeemer.{Buy, MarketplaceRedeemer, Withdraw}
use validation/payout

validator karbonstore {
  spend(
    datum: Option<MarketplaceDatum>,
    redeemer: MarketplaceRedeemer,
    _oref: OutputReference,
    tx: Transaction,
  ) {
    let Transaction { outputs, extra_signatories, .. } = tx
    expect Some(MarketplaceDatum { owner: seller, amount }) = datum
    let (marketplace_payout, seller_payout) =
      utils.calculate_payout_royalty(amount)
    when redeemer is {
      Buy -> and {
          payout.at_least(addresses.from_wallet(seller), seller_payout, outputs)?,
          payout.at_least(
            addresses.from_wallet(constants.roylaty_addr),
            marketplace_payout,
            outputs,
          )?,
        }
      Withdraw -> list.has(extra_signatories, seller.pkh)
    }
  }

  else(_) {
    fail
  }
}
