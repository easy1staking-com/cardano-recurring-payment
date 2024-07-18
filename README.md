# cardano-recurring-payment

This contract aims to facilitate the execution of recurring payments.

Users can lock funds in a contract, define the payee, the amount, the time of the first payment and then the cadence.

The contract makes use of a configuration datum locked at a ref input and guarded by an NFT.

The configuration will contain:
* the pkh of the authorised bot
* the bot operators fee

## High level description of the logic

Starting from `start_time` and for either unlimited time OR limited to a maximum `max_payment_delay_hours` number of hours, if specified, an authorised BOT is allowed to 
unlock the funds and:
1. send `amount_to_send` to a payee (identified by the payee credentials)
2. return to the contract the amount: initial funds - `amount_to_send` - tx fee - bot operator's fee
3. the new contract's datum must be identical to the previous except the `start_date` that will be incremented by the `payment_frenquency` value in seconds.

## Open points

* somewhere should be set a cap for the bot's fee, otherwise configuration could be updated to set the fees arbitrarily high, the cap should be at contract (constant) or datum level. Maybe customer should decide what's the maximum they want to pay