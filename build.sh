AIKEN=$1

echo "${AIKEN}"

aiken() {
  ${AIKEN} $*
}

# exit 0

# aiken build -t verbose &> /dev/null
aiken build &> /dev/null

## PREPROD ##

PREPROD_PROTOCOL_BOOT_UTXO="D8799F5820DB1133EE20002AD7DE8C3C1E5348C21DECFD5F3474A4BF9124EAB31FD04180EC01FF"
PREPROD_SETTINGS_POLICY_ID="581CCFAF54B77C8BBD8E3CE9A0AFCBCC51F02F484C583760F70BF873A21D"

## Settings
aiken blueprint apply -v settings.settings.spend $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
mv tmp preprod-spend-settings-plutus.json

aiken blueprint apply -v settings.settings.mint $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
mv tmp preprod-mint-settings-plutus.json

## Recurring payment
aiken blueprint apply -v automatic_payments.automatic_payments.spend $PREPROD_SETTINGS_POLICY_ID 2> /dev/null > tmp
mv tmp preprod-automatic-payments-plutus.json

## MAINNET ##

# MAINNET_PROTOCOL_BOOT_UTXO="d8799fd8799f58204f79db6c5e935d243340c44ab53f51dc3e6dd1c1a859f22f862482397b6a9281ff00ff"
MAINNET_SETTINGS_POLICY_ID="581c845a9b6c2341f6214cd00ac42e528440fd0c3707756ad1e1642f6809"

## Settings
# aiken blueprint apply -v settings.spend $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
# mv tmp preprod-spend-settings-plutus.json

# aiken blueprint apply -v settings.mint $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
# mv tmp preprod-mint-settings-plutus.json

## Recurring payment
aiken blueprint apply -v automatic_payments.automatic_payments 581c845a9b6c2341f6214cd00ac42e528440fd0c3707756ad1e1642f6809 2> /dev/null > tmp
mv tmp mainnet-automatic-payments-plutus.json
