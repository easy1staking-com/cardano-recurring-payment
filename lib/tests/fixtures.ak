use types/automatic_payments.{Datum, Hourly}

pub fn datum_template() {
  Datum(#"", None, [], #"", None, 1719835200000, None, Hourly, None, 1_000_000)
}
