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

PREPROD_PROTOCOL_BOOT_UTXO="D8799F58208CAC3945ED9866F45B2C7C2759C95D65B2D768E1C6596790156EFBBDAA69E89301FF"
PREPROD_SETTINGS_POLICY_ID="581CF11FE05B25B0F334837C974B747B062A71645BDCB3DED6C7329685E8"

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

MAINNET_PROTOCOL_BOOT_UTXO="D8799F58208C198E942F1F7A60E704AA1651333B45BCCD51653259204E4DAC38B559844DD800FF"
MAINNET_SETTINGS_POLICY_ID="581C66D403ABC1D6F1206B74C64204766E46601B88747575F6A0A02142A0"

## Settings
aiken blueprint apply -v settings.settings.spend $MAINNET_PROTOCOL_BOOT_UTXO -o plutus-tmp.json
mv plutus-tmp.json plutus.json

aiken blueprint apply -v settings.settings.mint $MAINNET_PROTOCOL_BOOT_UTXO -o plutus-tmp.json
mv plutus-tmp.json plutus.json

## Recurring payment
aiken blueprint apply -v automatic_payments.automatic_payments.spend $MAINNET_SETTINGS_POLICY_ID -o plutus-tmp.json
mv plutus-tmp.json plutus.json

### Saving mainnet plutus.json
mv plutus.json mainnet-plutus.json
