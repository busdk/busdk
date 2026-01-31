#!/usr/bin/env bash
set -e
set -x

# ==============================================================================
# BusDK E2E kirjanpito
# Vuosi: 2025
#
# Vaatimukset tälle testille:
# - Ei git-komentoja.
# - Käytä vain `bus` + standardit UNIX-komennot.
# - Käytä suomenkielisiä tiedostonimiä (ä->a, ö->o): tase, paivakirja, paakirja, tuloslaskelma...
# - Tarkista hakemistot/tiedostot suoraan `test -d` / `test -f`.
# - set -e ja set -x.
#
# Tämä skripti toimii samalla specinä: jos jokin bus-komento/flag puuttuu,
# se pitää toteuttaa JA dokumentoida BusDK-dokseihin.
# ==============================================================================

VUOSI=2025
TYOHAK="e2e_kirjanpito_${VUOSI}"

rm -rf "$TYOHAK"
mkdir -p "$TYOHAK"
cd "$TYOHAK"

command -v bus >/dev/null

# ------------------------------------------------------------------------------
# 1) Alusta workspace (fi-layout)
#
# VAATIMUS: bus init --layout fi luo suomenkieliset hakemistot ja perusdatasetit:
#   tilit/tilit.csv + tilit/tilit.schema.json
#   paivakirja/paivakirja_<VUOSI>.csv + .schema.json
#   laskut/(myyntilaskut, myyntilaskurivit, ostolaskut, ostolaskurivit).csv
#   alv/alv_kannat.csv + .schema.json
#   pankki/pankkitapahtumat_<VUOSI>.csv + .schema.json (voi syntyä myöhemmin importissa)
#   liitteet/liitteet.csv + .schema.json
#   raportit/
# Lisäksi datapackage.json juureen.
# ------------------------------------------------------------------------------
bus init --year "$VUOSI" --layout fi --currency EUR

test -f datapackage.json

test -d tilit
test -d paivakirja
test -d laskut
test -d alv
test -d pankki
test -d liitteet
test -d raportit

test -f "tilit/tilit.csv"
test -f "tilit/tilit.schema.json"

test -f "paivakirja/paivakirja_${VUOSI}.csv"
test -f "paivakirja/paivakirja_${VUOSI}.schema.json"

test -f "laskut/myyntilaskut.csv"
test -f "laskut/myyntilaskurivit.csv"
test -f "laskut/ostolaskut.csv"
test -f "laskut/ostolaskurivit.csv"

test -f "alv/alv_kannat.csv"
test -f "alv/alv_kannat.schema.json"

test -f "liitteet/liitteet.csv"
test -f "liitteet/liitteet.schema.json"

# ------------------------------------------------------------------------------
# 2) Tilikartta (minimi)
# ------------------------------------------------------------------------------
bus accounts add --code 1910 --name "Pankkitili" --type Asset
bus accounts add --code 1700 --name "Myyntisaamiset" --type Asset
bus accounts add --code 1600 --name "Koneet ja kalusto" --type Asset
bus accounts add --code 2880 --name "Ostovelat" --type Liability
bus accounts add --code 2930 --name "ALV-tili" --type Liability
bus accounts add --code 2000 --name "SVOP" --type Equity
bus accounts add --code 3000 --name "Liikevaihto" --type Income
bus accounts add --code 4000 --name "Ostot" --type Expense
bus accounts add --code 6590 --name "Pankkikulut" --type Expense

# ------------------------------------------------------------------------------
# 3) ALV-kanta (vuodelle 2025 käytetään 25.5 tässä testissä)
#
# VAATIMUS: alv-kannat on eksplisiittinen taulu, jota laskut ja alv-raportit voivat käyttää.
# ------------------------------------------------------------------------------
bus vat rates set --code ALV25_5 --percent 25.5 --valid-from "${VUOSI}-01-01"
test -f "alv/alv_kannat.csv"

# ------------------------------------------------------------------------------
# 4) Tositteet ja liitteet (tekstitiedostoina)
# ------------------------------------------------------------------------------
mkdir -p aineisto
mkdir -p liitteet/tiedostot

cat > "aineisto/tosite_TOS-${VUOSI}-0001.txt" <<EOF
TOS-${VUOSI}-0001 Paomasijoitus ${VUOSI}-01-05: 2000.00 EUR
EOF

cat > "aineisto/tosite_TOS-${VUOSI}-0002.txt" <<EOF
TOS-${VUOSI}-0002 Laptop-osto ${VUOSI}-01-10: netto 800.00, ALV 204.00, yhteensa 1004.00 EUR
EOF

cat > "aineisto/tosite_TOS-${VUOSI}-0101.txt" <<EOF
TOS-${VUOSI}-0101 Myyntilasku INV-1001 ${VUOSI}-02-01: veroton 1000.00, ALV 255.00, yhteensa 1255.00 EUR
EOF

bus attachments add \
  --id ATT-${VUOSI}-0001 \
  --voucher-id TOS-${VUOSI}-0001 \
  --date "${VUOSI}-01-05" \
  --kind tosite \
  --desc "Paomasijoitus" \
  --file "aineisto/tosite_TOS-${VUOSI}-0001.txt"

bus attachments add \
  --id ATT-${VUOSI}-0002 \
  --voucher-id TOS-${VUOSI}-0002 \
  --date "${VUOSI}-01-10" \
  --kind lasku \
  --desc "Laptop-osto" \
  --file "aineisto/tosite_TOS-${VUOSI}-0002.txt"

bus attachments add \
  --id ATT-${VUOSI}-0101 \
  --voucher-id TOS-${VUOSI}-0101 \
  --date "${VUOSI}-02-01" \
  --kind lasku \
  --desc "Myyntilasku INV-1001" \
  --file "aineisto/tosite_TOS-${VUOSI}-0101.txt"

test -f "liitteet/liitteet.csv"

# ------------------------------------------------------------------------------
# 5) Kirjaukset ja laskut (suoriteperuste)
# ------------------------------------------------------------------------------
# Paomasijoitus: Dr 1910, Cr 2000
bus journal record \
  --date "${VUOSI}-01-05" \
  --voucher-id "TOS-${VUOSI}-0001" \
  --desc "Paomasijoitus pankkitilille" \
  --debit  "1910=2000.00" \
  --credit "2000=2000.00"

# Ostolasku: Dr 1600 800, Dr 2930 204, Cr 2880 1004
bus invoices create \
  --type purchase \
  --invoice-id "OSL-0001" \
  --date "${VUOSI}-01-10" \
  --vendor "Verkkokauppa Oy" \
  --attachment-id "ATT-${VUOSI}-0002" \
  --voucher-id "TOS-${VUOSI}-0002" \
  --line "Laptop|1|kpl|800.00|ALV25_5|1600" \
  --post-to-journal \
  --ap-account 2880 \
  --vat-account 2930

# Myyntilasku: Dr 1700 1255, Cr 3000 1000, Cr 2930 255
bus invoices create \
  --type sales \
  --invoice-id "INV-1001" \
  --date "${VUOSI}-02-01" \
  --customer "Asiakas Oy" \
  --attachment-id "ATT-${VUOSI}-0101" \
  --voucher-id "TOS-${VUOSI}-0101" \
  --due "${VUOSI}-03-03" \
  --line "Konsultointi|10|h|100.00|ALV25_5|3000" \
  --post-to-journal \
  --ar-account 1700 \
  --vat-account 2930

test -f "paivakirja/paivakirja_${VUOSI}.csv"
test -f "laskut/myyntilaskut.csv"
test -f "laskut/ostolaskut.csv"

# ------------------------------------------------------------------------------
# 6) Pankkitapahtumat: import ja tasmaytys
# ------------------------------------------------------------------------------
cat > "aineisto/pankki_${VUOSI}.csv" <<'CSV'
date,amount,description,counterparty,reference
2025-01-10,-1004.00,Laptop-osto,Verkkokauppa Oy,OSL-0001
2025-02-14,1255.00,Maksu myyntilaskuun,Asiakas Oy,INV-1001
2025-02-28,-5.00,Pankkipalvelumaksu,Pankki,
CSV

bus bank import --file "aineisto/pankki_${VUOSI}.csv" --id-prefix "BTX-${VUOSI}-"

test -f "pankki/pankkitapahtumat_${VUOSI}.csv"
test -f "pankki/pankkitapahtumat_${VUOSI}.schema.json"

# Ostolaskun maksu: Dr 2880, Cr 1910
bus reconcile apply-invoice-payment \
  --bank-txn-id "BTX-${VUOSI}-0001" \
  --invoice-id "OSL-0001" \
  --cash-account 1910 \
  --ap-account 2880 \
  --voucher-id "TOS-${VUOSI}-0201" \
  --desc "Ostolaskun OSL-0001 maksu"

# Myyntilaskun suoritus: Dr 1910, Cr 1700
bus reconcile apply-invoice-receipt \
  --bank-txn-id "BTX-${VUOSI}-0002" \
  --invoice-id "INV-1001" \
  --cash-account 1910 \
  --ar-account 1700 \
  --voucher-id "TOS-${VUOSI}-0202" \
  --desc "Myyntilaskun INV-1001 suoritus"

# Pankkikulu: Dr 6590, Cr 1910
bus reconcile categorize \
  --bank-txn-id "BTX-${VUOSI}-0003" \
  --voucher-id "TOS-${VUOSI}-0203" \
  --desc "Pankkipalvelumaksu" \
  --debit  "6590=5.00" \
  --credit "1910=5.00"

# ------------------------------------------------------------------------------
# 7) ALV-ilmoitus + validointi
# ------------------------------------------------------------------------------
bus vat report --period "${VUOSI}Q1" --out "alv/alv_ilmoitus_${VUOSI}Q1.csv"
test -f "alv/alv_ilmoitus_${VUOSI}Q1.csv"

bus validate --strict
test -f "paivakirja/paivakirja_${VUOSI}.csv"

# ------------------------------------------------------------------------------
# 8) Raportit (suomeksi)
# ------------------------------------------------------------------------------
bus reports tuloslaskelma --year "$VUOSI" --out "raportit/tuloslaskelma_${VUOSI}.csv"
bus reports tase --as-of "${VUOSI}-12-31" --out "raportit/tase_${VUOSI}-12-31.csv"
bus reports paivakirja --year "$VUOSI" --out "raportit/paivakirja_${VUOSI}.csv"
bus reports paakirja --year "$VUOSI" --out "raportit/paakirja_${VUOSI}.csv"

test -f "raportit/tuloslaskelma_${VUOSI}.csv"
test -f "raportit/tase_${VUOSI}-12-31.csv"
test -f "raportit/paivakirja_${VUOSI}.csv"
test -f "raportit/paakirja_${VUOSI}.csv"

# ------------------------------------------------------------------------------
# 9) Verotarkastuspaketti
# ------------------------------------------------------------------------------
bus reports verotarkastuspaketti --period "$VUOSI" --out "raportit/verotarkastuspaketti_${VUOSI}.zip"
test -f "raportit/verotarkastuspaketti_${VUOSI}.zip"

echo "OK: e2e kirjanpito ${VUOSI} valmis: $(pwd)"
