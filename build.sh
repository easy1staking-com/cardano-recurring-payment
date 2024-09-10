AIKEN=$1

echo "${AIKEN}"

aiken() {
  ${AIKEN} $*
}

# exit 0

aiken build -t verbose &> /dev/null

PREPROD_PROTOCOL_BOOT_UTXO="d8799fd8799f58204f79db6c5e935d243340c44ab53f51dc3e6dd1c1a859f22f862482397b6a9281ff00ff"
PREPROD_SETTINGS_POLICY_ID="581cb29a6ffd079d50bb4b130bc76a0a13e10eeceb67328bb3e5e46c4eaa"

## Settings
aiken blueprint apply -v settings.spend $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
mv tmp preprod-spend-settings-plutus.json

aiken blueprint apply -v settings.mint $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
mv tmp preprod-mint-settings-plutus.json

## Recurring payment
aiken blueprint apply -v automatic_payments.automatic_payments $PREPROD_SETTINGS_POLICY_ID 2> /dev/null > tmp
mv tmp preprod-automatic-payments-plutus.json
