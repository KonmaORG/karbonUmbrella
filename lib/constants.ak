use types/wallet.{Wallet}

/// The asset name for the unique identification token used to reference the configuration datum.
pub const identication_tkn = "KARBON_IDENTIFICATION"

/// The royalty percentage charged on marketplace transactions, specified as an integer (e.g., 3 for 3%).
pub const royalty_amt: Int = 3

/// The wallet address where marketplace royalties are sent.
pub const roylaty_addr: Wallet =
  Wallet {
    pkh: #"70840826b6f202d0b9a1ade2b75b5eca9d326e6a9c7117c071ab4704",
    sc: "",
  }
