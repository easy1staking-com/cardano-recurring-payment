use cardano/address
use types/automatic_payments.{AutomatedPayment}

pub fn datum_template() {
  AutomatedPayment(
    #"",
    [],
    address.from_verification_key(#""),
    1719835200000,
    None,
    Some(1),
    None,
    1_000_000,
  )
}
