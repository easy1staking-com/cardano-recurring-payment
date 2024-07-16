use aiken/interval.{after, between}
use aiken/transaction/credential.{VerificationKeyCredential}
use automatic_payments.{Datum, Hourly, is_payment_time_valid}

test is_payment_time_valid_succeed_start_time_only() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      None,
      #"",
    )
  is_payment_time_valid(datum, after(1719838800000))
}

test is_payment_time_valid_succeed_start_time_only_interval() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      None,
      #"",
    )
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_and_max_delay() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  is_payment_time_valid(datum, between(1719838800000, 1719849600000))
}

test is_payment_time_valid_succeed_start_time_overlap_and_max_delay() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  is_payment_time_valid(datum, between(1719835200000, 1719849600000))
}

test is_payment_time_valid_fail_start_time_and_max_delay_overlap() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  !is_payment_time_valid(datum, between(1719831600000, 1719853200000))
}

test is_payment_time_valid_fail_earlier_start_time() {
  let datum =
    Datum(
      #"",
      [],
      VerificationKeyCredential(#""),
      None,
      1719835200000,
      Hourly,
      Some(5),
      #"",
    )
  !is_payment_time_valid(datum, after(1719831600000))
}
