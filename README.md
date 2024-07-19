# cardano-recurring-payment

This contract aims to facilitate the execution of recurring payments.

Users can lock funds in a contract, define the payee, the amount, the time of the first payment and then the cadence.

The contract makes use of a configuration datum locked at a ref input and guarded by an NFT.

The configuration will contain:
* the pkh of the authorised bot
* the bot operators fee

## The HOSKY use case

I have a wallet delegated to `WRFGS` a charity Stake Pool. The wallet I'm using is an hardware wallet.
`WRFGS` is a Stake Pool that is part of the Doggie Bowl and allows delegates to withdraw Hosky tokens at each epoch.
In order to collect the rewards, 2 $ada must be sent from the wallet to the doggie bowl.

Remembering to send 2 $ada every 5 days is hard, and using an HW wallet is annoying so, using an automated system to perform payments is ideal.

Doggie bowl is franken address aware, so when tokens are sent back, the backend knows to send them to address that was used to register the stake key with a pool.

For this reason I could set up, with any wallet, the recurring payment bot by sending funds to a mingled address: pkh of the script combined to the stake address of the 
wallet I want to collect the rewards for, and the set the initial date to let's say 1 day after next epoch, and set frequency to 5 days.

## High level description of the logic

Starting from `start_time` and for either unlimited time OR limited to a maximum `max_payment_delay_hours` number of hours, if specified, an authorised BOT is allowed to 
unlock the funds and:
1. send `amount_to_send` to a payee (identified by the payee credentials)
2. return to the contract the amount: initial funds - `amount_to_send` - tx fee - bot operator's fee
3. the new contract's datum must be identical to the previous except the `start_date` that will be incremented by the `payment_frenquency` value in seconds.

## Known issues:
 