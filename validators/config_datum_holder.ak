//// this contract hold the Config Datum for all the script and will also hold the IdentificationNft as well
//// to spedn form this contract the minimum multisignatory should sign it.

use cardano/transaction.{Transaction}
use cardano/tx
use types/datum.{ConfigDatum}

validator config_datum_holder {
  spend(datum: Option<ConfigDatum>, _redeemer, _oref, tx: Transaction) {
    expect Some(datum) = datum
    let Transaction { extra_signatories, .. } = tx
    // must be true when atleast_signedby from datum value
    tx.verify_multisig(
      extra_signatories,
      datum.multisig_refutxoupdate.signers,
      datum.multisig_refutxoupdate.required,
    )
  }

  else(_) {
    fail
  }
}
