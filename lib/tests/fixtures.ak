use aiken/transaction/credential.{VerificationKeyCredential}
use types/automatic_payments.{Datum, Hourly}

pub fn datum_template() {
  Datum(
    #"",
    None,
    [],
    VerificationKeyCredential(#""),
    None,
    1719835200000,
    Hourly,
    None,
  )
}
