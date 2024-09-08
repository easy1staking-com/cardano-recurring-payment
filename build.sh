AIKEN=$1

echo "${AIKEN}"

aiken() {
  ${AIKEN} $*
}

# exit 0

aiken build &> /dev/null

PREPROD_PROTOCOL_BOOT_UTXO="d8799fd8799f5820aadaac3863a0e43da3f4464c2fdccada8d39ffe3a041e01fc5849e8a720e9cf3ff00ff"

aiken blueprint apply -v settings.spend $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
mv tmp preprod-spend-settings-plutus.json

aiken blueprint apply -v settings.mint $PREPROD_PROTOCOL_BOOT_UTXO 2> /dev/null > tmp
mv tmp preprod-mint-settings-plutus.json
