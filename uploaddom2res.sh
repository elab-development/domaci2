#!/bin/bash

PREFIX=$1
RESULTS_DIR=${2:-.}

AZURE_ENDPOINT="https://dom2servis-d2g5eucqeugjbgbn.westeurope-01.azurewebsites.net/api/submit-result"

if [ -z "$PREFIX" ]; then
  echo "Upotreba: ./upload-grade-domaci2.sh <studentski-prefiks> [folder-sa-rezultatima]"
  echo "Primer: ./upload-grade-domaci2.sh tn20185005"
  echo "Primer: ./upload-grade-domaci2.sh tn20185005 ./rezultati"
  exit 1
fi

SUMMARY_FILE="$RESULTS_DIR/sumarna-provera-${PREFIX}.txt"
ZIP_FILE="$RESULTS_DIR/dokazi-${PREFIX}.zip"
UPLOAD_RESPONSE_FILE="$RESULTS_DIR/azure-upload-${PREFIX}.json"

echo "======================================"
echo "UPLOAD OCENE ZA: $PREFIX"
echo "======================================"
echo ""

# --------------------------------------
# Stopiranje svih aktivnih kontejnera
# --------------------------------------

echo "1. STOPIRANJE SVIH AKTIVNIH KONTEJNERA"
echo "--------------------------------------"

RUNNING_CONTAINERS=$(docker ps -q)

if [ -n "$RUNNING_CONTAINERS" ]; then
  docker stop $RUNNING_CONTAINERS > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "[OK] Svi aktivni kontejneri su stopirani."
  else
    echo "[UPOZORENJE] Došlo je do problema prilikom stopiranja kontejnera."
  fi
else
  echo "[INFO] Nema aktivnih kontejnera za stopiranje."
fi

echo ""
echo "Napomena: kontejneri nisu obrisani, samo su stopirani."
echo ""

# --------------------------------------
# Provera fajlova za upload
# --------------------------------------

echo "2. PROVERA FAJLOVA ZA UPLOAD"
echo "--------------------------------------"

if [ ! -f "$SUMMARY_FILE" ]; then
  echo "[GREŠKA] Nije pronađen fajl sa sumarnom proverom:"
  echo "$SUMMARY_FILE"
  exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
  echo "[GREŠKA] Nije pronađen ZIP fajl sa dokazima:"
  echo "$ZIP_FILE"
  echo "Upload ocene nije dozvoljen bez prethodno kreiranog ZIP fajla."
  exit 1
fi

GRADE=$(grep "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA" "$SUMMARY_FILE" | tail -n 1 | sed -E 's/.*: ([0-9]+)\/[0-9]+.*/\1/')

if ! [[ "$GRADE" =~ ^[0-9]+$ ]]; then
  echo "[GREŠKA] Nije moguće pročitati broj poena iz fajla:"
  echo "$SUMMARY_FILE"
  echo ""
  echo "Očekivani format linije:"
  echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: 8/10"
  exit 1
fi

echo "[OK] Pronađen summary fajl: $SUMMARY_FILE"
echo "[OK] Pronađen ZIP fajl: $ZIP_FILE"
echo "[OK] Broj poena za upload: $GRADE"
echo ""

# --------------------------------------
# Upload rezultata na Azure
# --------------------------------------

echo "3. UPLOAD REZULTATA NA AZURE"
echo "--------------------------------------"

read -s -p "Unesite upload šifru: " UPLOAD_SECRET
echo ""
echo ""

if [ -z "$UPLOAD_SECRET" ]; then
  echo "[GREŠKA] Upload šifra nije uneta."
  exit 1
fi

echo "Šaljem rezultat na Azure..."
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$AZURE_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-upload-secret: $UPLOAD_SECRET" \
  -d "{\"username\":\"$PREFIX\",\"grade\":$GRADE}")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | sed "s/HTTP_STATUS://")
BODY=$(echo "$RESPONSE" | sed "/HTTP_STATUS:/d")

echo "$BODY" > "$UPLOAD_RESPONSE_FILE"

echo "Azure odgovor:"
echo "$BODY"
echo ""

if [ "$HTTP_STATUS" = "201" ]; then
  echo "[OK] Rezultat je uspešno poslat na Azure Table Storage."
  echo "[OK] Odgovor je sačuvan u: $UPLOAD_RESPONSE_FILE"
else
  echo "[GREŠKA] Upload nije uspeo. HTTP status: $HTTP_STATUS"
  echo "Odgovor je sačuvan u: $UPLOAD_RESPONSE_FILE"
  exit 1
fi