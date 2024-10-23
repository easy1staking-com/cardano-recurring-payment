AIKEN=$1

echo "${AIKEN}"

aiken() {
  ${AIKEN} $*
}

# exit 0


## PREPROD ##

### First Step rebuild

# aiken build -t verbose &> /dev/null
aiken build &> /dev/null

PREPROD_PROTOCOL_BOOT_UTXO="D8799F5820F57F6F626F43A026A11654F4EE88B5F4EF52166B0A2083FE2ED1D822E6045B8001FF"
PREPROD_SETTINGS_POLICY_ID="581CD8EBA846AAEF90FF9A5C23C4648695D10707D9A5A27DF121C11E3961"

## Settings
aiken blueprint apply -v settings.settings.spend $PREPROD_PROTOCOL_BOOT_UTXO -o plutus-tmp.json
mv plutus-tmp.json plutus.json

aiken blueprint apply -v settings.settings.mint $PREPROD_PROTOCOL_BOOT_UTXO -o plutus-tmp.json
mv plutus-tmp.json plutus.json

## Recurring payment
aiken blueprint apply -v automatic_payments.automatic_payments.spend $PREPROD_SETTINGS_POLICY_ID -o plutus-tmp.json
mv plutus-tmp.json plutus.json

### Saving preprod plutus.json
mv plutus.json preprod-plutus.json

## MAINNET ##

### First Step rebuild

# aiken build -t verbose &> /dev/null
aiken build &> /dev/null

# MAINNET_PROTOCOL_BOOT_UTXO="d8799fd8799f58204f79db6c5e935d243340c44ab53f51dc3e6dd1c1a859f22f862482397b6a9281ff00ff"
MAINNET_SETTINGS_POLICY_ID="581c845a9b6c2341f6214cd00ac42e528440fd0c3707756ad1e1642f6809"

## Settings
# aiken blueprint apply -v settings.spend $PREPROD_PROTOCOL_BOOT_UTXO 2> -o plutus-tmp.json
# mv tmp preprod-spend-settings-plutus.json

# aiken blueprint apply -v settings.mint $PREPROD_PROTOCOL_BOOT_UTXO 2> -o plutus-tmp.json
# mv tmp preprod-mint-settings-plutus.json

## Recurring payment
aiken blueprint apply -v automatic_payments.automatic_payments.spend $MAINNET_SETTINGS_POLICY_ID -o plutus-tmp.json
mv plutus-tmp.json plutus.json

### Saving mainnet plutus.json
mv plutus.json mainnet-plutus.json
