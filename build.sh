AIKEN=$1

echo "${AIKEN}"

aiken() {
  ${AIKEN} $*
}

# exit 0

aiken build -t verbose &> /dev/null
# aiken build &> /dev/null

## PREPROD ##

PREPROD_PROTOCOL_BOOT_UTXO="D8799F5820F7AB6DE61468C99E2112919BA48E9717FD219C4A98E5958992214BB715274EAD00FF"
PREPROD_SETTINGS_POLICY_ID="581c92ab0d02e2a5de7ef53393e8f352e6123b86268860d4359951423df2"

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
