#!/bin/bash

PREFIX=$1

if [ -z "$PREFIX" ]; then
  echo "Upotreba: ./check-domaci2.sh <studentski-prefiks>"
  echo "Primer: ./check-domaci2.sh pg20220043"
  exit 1
fi

IMG1="${PREFIX}-img"
IMG2="${PREFIX}-img:v2"

CONT1="${PREFIX}-cont1"
CONT2="${PREFIX}-cont2"
CONT3="${PREFIX}-cont3"
MYSQL_CONT="${PREFIX}-server"
APP_DB_CONT="${PREFIX}-baza1"

VOL="${PREFIX}-vol"
NET="${PREFIX}-network"

REPORT="provera-${PREFIX}.txt"

echo "PROVERA DOMAĆEG 2 ZA: $PREFIX" > "$REPORT"
echo "======================================" >> "$REPORT"
echo "" >> "$REPORT"

check_exists() {
  local TYPE=$1
  local NAME=$2
  local COMMAND=$3

  if eval "$COMMAND" > /dev/null 2>&1; then
    echo "[OK] $TYPE postoji: $NAME"
    echo "[OK] $TYPE postoji: $NAME" >> "$REPORT"
  else
    echo "[NEDOSTAJE] $TYPE ne postoji: $NAME"
    echo "[NEDOSTAJE] $TYPE ne postoji: $NAME" >> "$REPORT"
  fi
}

echo "1. PROVERA IMAGE-A"
echo "1. PROVERA IMAGE-A" >> "$REPORT"

check_exists "Image" "$IMG1" "docker image inspect $IMG1"
check_exists "Image" "$IMG2" "docker image inspect $IMG2"

echo "" >> "$REPORT"
echo ""

echo "2. PROVERA KONTEJNERA"
echo "2. PROVERA KONTEJNERA" >> "$REPORT"

check_exists "Kontejner" "$CONT1" "docker container inspect $CONT1"
check_exists "Kontejner" "$CONT2" "docker container inspect $CONT2"
check_exists "Kontejner" "$CONT3" "docker container inspect $CONT3"
check_exists "Kontejner" "$MYSQL_CONT" "docker container inspect $MYSQL_CONT"
check_exists "Kontejner" "$APP_DB_CONT" "docker container inspect $APP_DB_CONT"

echo "" >> "$REPORT"
echo ""

echo "3. PROVERA VOLUME-A"
echo "3. PROVERA VOLUME-A" >> "$REPORT"

check_exists "Volume" "$VOL" "docker volume inspect $VOL"

echo "" >> "$REPORT"
echo ""

echo "4. PROVERA MREŽE"
echo "4. PROVERA MREŽE" >> "$REPORT"

check_exists "Network" "$NET" "docker network inspect $NET"

echo "" >> "$REPORT"
echo ""

echo "5. PROVERA DA LI SU KONTEJNERI U MREŽI"
echo "5. PROVERA DA LI SU KONTEJNERI U MREŽI" >> "$REPORT"

for C in "$MYSQL_CONT" "$APP_DB_CONT"; do
  if docker network inspect "$NET" | grep -q "$C"; then
    echo "[OK] Kontejner $C je povezan na mrežu $NET"
    echo "[OK] Kontejner $C je povezan na mrežu $NET" >> "$REPORT"
  else
    echo "[NEDOSTAJE] Kontejner $C nije povezan na mrežu $NET"
    echo "[NEDOSTAJE] Kontejner $C nije povezan na mrežu $NET" >> "$REPORT"
  fi
done

echo "" >> "$REPORT"
echo ""

echo "6. PROVERA PORTOVA"
echo "6. PROVERA PORTOVA" >> "$REPORT"

for C in "$CONT1" "$CONT2" "$CONT3" "$APP_DB_CONT"; do
  echo "Portovi za $C:"
  echo "Portovi za $C:" >> "$REPORT"
  docker port "$C" 2>/dev/null | tee -a "$REPORT"
  echo "" >> "$REPORT"
done

echo ""
echo "7. PROVERA MYSQL BAZE"
echo "7. PROVERA MYSQL BAZE" >> "$REPORT"

if docker container inspect "$MYSQL_CONT" > /dev/null 2>&1; then

  echo "[OK] MySQL kontejner postoji: $MYSQL_CONT"
  echo "[OK] MySQL kontejner postoji: $MYSQL_CONT" >> "$REPORT"

  docker exec "$MYSQL_CONT" mysql -uroot -ppass -e "
  SHOW DATABASES;
  SELECT user, host FROM mysql.user;
  " > "provera-baze-${PREFIX}.txt" 2>&1

  echo "[OK] Rezultat direktne provere baze je sačuvan u provera-baze-${PREFIX}.txt"
  echo "[OK] Rezultat direktne provere baze je sačuvan u provera-baze-${PREFIX}.txt" >> "$REPORT"

  if grep -q "feedback_db" "provera-baze-${PREFIX}.txt"; then
    echo "[OK] Baza feedback_db postoji"
    echo "[OK] Baza feedback_db postoji" >> "$REPORT"
  else
    echo "[NEDOSTAJE] Baza feedback_db nije pronađena"
    echo "[NEDOSTAJE] Baza feedback_db nije pronađena" >> "$REPORT"
  fi

  if grep -q "fuser" "provera-baze-${PREFIX}.txt"; then
    echo "[OK] Korisnik fuser postoji"
    echo "[OK] Korisnik fuser postoji" >> "$REPORT"
  else
    echo "[NEDOSTAJE] Korisnik fuser nije pronađen"
    echo "[NEDOSTAJE] Korisnik fuser nije pronađen" >> "$REPORT"
  fi

  echo ""
  echo "" >> "$REPORT"
  echo "7.1 PROVERA LOG FAJLA IZ MYSQL KONTEJNERA"
  echo "7.1 PROVERA LOG FAJLA IZ MYSQL KONTEJNERA" >> "$REPORT"

  if docker exec "$MYSQL_CONT" test -f /tmp/provera_baze.log; then
    echo "[OK] Log fajl postoji u MySQL kontejneru: /tmp/provera_baze.log"
    echo "[OK] Log fajl postoji u MySQL kontejneru: /tmp/provera_baze.log" >> "$REPORT"

    docker exec "$MYSQL_CONT" cat /tmp/provera_baze.log > "mysql-log-${PREFIX}.txt" 2>&1

    echo "[OK] Sadržaj log fajla je sačuvan u mysql-log-${PREFIX}.txt"
    echo "[OK] Sadržaj log fajla je sačuvan u mysql-log-${PREFIX}.txt" >> "$REPORT"

    if grep -q "feedback_db" "mysql-log-${PREFIX}.txt"; then
      echo "[OK] Log fajl sadrži bazu feedback_db"
      echo "[OK] Log fajl sadrži bazu feedback_db" >> "$REPORT"
    else
      echo "[UPOZORENJE] Log fajl ne sadrži bazu feedback_db"
      echo "[UPOZORENJE] Log fajl ne sadrži bazu feedback_db" >> "$REPORT"
    fi

    if grep -q "fuser" "mysql-log-${PREFIX}.txt"; then
      echo "[OK] Log fajl sadrži korisnika fuser"
      echo "[OK] Log fajl sadrži korisnika fuser" >> "$REPORT"
    else
      echo "[UPOZORENJE] Log fajl ne sadrži korisnika fuser"
      echo "[UPOZORENJE] Log fajl ne sadrži korisnika fuser" >> "$REPORT"
    fi

  else
    echo "[NEDOSTAJE] Log fajl /tmp/provera_baze.log ne postoji u MySQL kontejneru"
    echo "[NEDOSTAJE] Log fajl /tmp/provera_baze.log ne postoji u MySQL kontejneru" >> "$REPORT"
  fi

else
  echo "[NEDOSTAJE] MySQL kontejner nije pronađen"
  echo "[NEDOSTAJE] MySQL kontejner nije pronađen" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo ""

echo "8. PROVERA API RUTE /api/feedback"
echo "8. PROVERA API RUTE /api/feedback" >> "$REPORT"

API_RESPONSE=$(curl -s -o "api-feedback-${PREFIX}.json" -w "%{http_code}" "http://localhost:5000/api/feedback")

if [ "$API_RESPONSE" = "200" ]; then
  echo "[OK] API ruta http://localhost:5000/api/feedback vraća status 200"
  echo "[OK] API ruta http://localhost:5000/api/feedback vraća status 200" >> "$REPORT"
  echo "JSON odgovor je sačuvan u api-feedback-${PREFIX}.json"
  echo "JSON odgovor je sačuvan u api-feedback-${PREFIX}.json" >> "$REPORT"
else
  echo "[PROBLEM] API ruta ne vraća status 200. Status: $API_RESPONSE"
  echo "[PROBLEM] API ruta ne vraća status 200. Status: $API_RESPONSE" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo ""

echo "9. PROVERA FEEDBACK FAJLOVA U VOLUME-U"
echo "9. PROVERA FEEDBACK FAJLOVA U VOLUME-U" >> "$REPORT"

if docker volume inspect "$VOL" > /dev/null 2>&1; then
  MOUNTPOINT=$(docker volume inspect "$VOL" --format '{{ .Mountpoint }}')

  echo "[OK] Volume postoji: $VOL"
  echo "[OK] Volume postoji: $VOL" >> "$REPORT"

  echo "Mountpoint: $MOUNTPOINT"
  echo "Mountpoint: $MOUNTPOINT" >> "$REPORT"

  echo "Sadržaj mountpoint direktorijuma:"
  echo "Sadržaj mountpoint direktorijuma:" >> "$REPORT"

  sudo ls -la "$MOUNTPOINT" | tee -a "$REPORT"

  echo "" >> "$REPORT"

  FILE_NO_DB=$(sudo find "$MOUNTPOINT" -type f -name "${PREFIX}-fajl-*.txt" | head -n 1)

  if [ -n "$FILE_NO_DB" ]; then
    echo "[OK] Pronađen feedback fajl bez baze: $FILE_NO_DB"
    echo "[OK] Pronađen feedback fajl bez baze: $FILE_NO_DB" >> "$REPORT"
  else
    echo "[UPOZORENJE] Nije pronađen fajl po šablonu ${PREFIX}-fajl-*.txt"
    echo "[UPOZORENJE] Nije pronađen fajl po šablonu ${PREFIX}-fajl-*.txt" >> "$REPORT"
  fi

  FILE_WITH_DB=$(sudo find "$MOUNTPOINT" -type f -name "${PREFIX}-fajlbaza-*.txt" | head -n 1)

  if [ -n "$FILE_WITH_DB" ]; then
    echo "[OK] Pronađen feedback fajl kreiran uz bazu: $FILE_WITH_DB"
    echo "[OK] Pronađen feedback fajl kreiran uz bazu: $FILE_WITH_DB" >> "$REPORT"
  else
    echo "[UPOZORENJE] Nije pronađen fajl po šablonu ${PREFIX}-fajlbaza-*.txt"
    echo "[UPOZORENJE] Nije pronađen fajl po šablonu ${PREFIX}-fajlbaza-*.txt" >> "$REPORT"
  fi

else
  echo "[NEDOSTAJE] Volume ne postoji: $VOL"
  echo "[NEDOSTAJE] Volume ne postoji: $VOL" >> "$REPORT"
fi



echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "KRAJ PROVERE" >> "$REPORT"

echo ""
echo "Provera završena."
echo "Glavni izveštaj: $REPORT"
echo "Dodatni fajlovi:"
echo "- provera-baze-${PREFIX}.txt"
echo "- provera-volume-${PREFIX}.txt"
echo "- api-feedback-${PREFIX}.json"

echo ""
echo "======================================"
echo "SUMARNA PROVERA PO ZAHTEVIMA"
echo "======================================"

echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "SUMARNA PROVERA PO ZAHTEVIMA" >> "$REPORT"
echo "======================================" >> "$REPORT"

SUMMARY_FILE="sumarna-provera-${PREFIX}.txt"

echo "SUMARNA PROVERA ZA: $PREFIX" > "$SUMMARY_FILE"
echo "======================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

OK_COUNT=0
TOTAL_REQUIREMENTS=10

print_requirement_result() {
  local REQ=$1
  local STATUS=$2
  local MESSAGE=$3

  if [ "$STATUS" = "OK" ]; then
    OK_COUNT=$((OK_COUNT + 1))
  fi

  echo "Zahtev $REQ: [$STATUS] $MESSAGE"
  echo "Zahtev $REQ: [$STATUS] $MESSAGE" >> "$REPORT"
  echo "Zahtev $REQ: [$STATUS] $MESSAGE" >> "$SUMMARY_FILE"
}

is_container_running() {
  local CONTAINER=$1
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]
}

is_port_available() {
  local PORT=$1
  curl -s --max-time 5 "http://localhost:$PORT" > /dev/null 2>&1
}

is_container_using_volume() {
  local CONTAINER=$1
  local VOLUME=$2
  docker inspect "$CONTAINER" 2>/dev/null | grep -q "\"Name\": \"$VOLUME\""
}

is_container_in_network() {
  local CONTAINER=$1
  local NETWORK=$2
  docker network inspect "$NETWORK" 2>/dev/null | grep -q "\"Name\": \"$CONTAINER\""
}

# --------------------------------------
# Zahtev 1
# Dockerfile postoji + image kreiran
# --------------------------------------

DOCKERFILE_PATH=$(find . -maxdepth 1 -type f -iname "dockerfile" | head -n 1)

if [ -n "$DOCKERFILE_PATH" ] && docker image inspect "$IMG1" > /dev/null 2>&1; then
  print_requirement_result "1" "OK" "Dockerfile postoji ($DOCKERFILE_PATH) i image $IMG1 je kreiran."
else
  print_requirement_result "1" "NIJE OK" "Nedostaje Dockerfile/dockerfile ili image $IMG1 nije kreiran."
fi

# --------------------------------------
# Zahtev 2
# cont1 postoji, aktivan je i aplikacija radi na 3001
# --------------------------------------

if docker container inspect "$CONT1" > /dev/null 2>&1 \
  && is_container_running "$CONT1" \
  && is_port_available "3001"; then
  print_requirement_result "2" "OK" "Kontejner $CONT1 postoji, aktivan je i aplikacija je dostupna na portu 3001."
else
  print_requirement_result "2" "NIJE OK" "Kontejner $CONT1 ne postoji, nije aktivan ili aplikacija nije dostupna na portu 3001."
fi

# --------------------------------------
# Zahtev 3
# cont2 postoji, aktivan je, koristi volume i radi na 4000
# --------------------------------------

if docker container inspect "$CONT2" > /dev/null 2>&1 \
  && is_container_running "$CONT2" \
  && is_container_using_volume "$CONT2" "$VOL" \
  && is_port_available "4000"; then
  print_requirement_result "3" "OK" "Kontejner $CONT2 postoji, aktivan je, koristi volume $VOL i aplikacija je dostupna na portu 4000."
else
  print_requirement_result "3" "NIJE OK" "Kontejner $CONT2 ne postoji, nije aktivan, ne koristi volume $VOL ili aplikacija nije dostupna na portu 4000."
fi

# --------------------------------------
# Zahtev 4
# volume mountpoint ima fajlove + cont3 postoji, aktivan je, koristi volume i radi na 4001
# --------------------------------------

VOLUME_HAS_FILES=false

if docker volume inspect "$VOL" > /dev/null 2>&1; then
  MOUNTPOINT=$(docker volume inspect "$VOL" --format '{{ .Mountpoint }}')
  if sudo find "$MOUNTPOINT" -type f -name "*.txt" | grep -q ".txt"; then
    VOLUME_HAS_FILES=true
  fi
fi

if [ "$VOLUME_HAS_FILES" = true ] \
  && docker container inspect "$CONT3" > /dev/null 2>&1 \
  && is_container_running "$CONT3" \
  && is_container_using_volume "$CONT3" "$VOL" \
  && is_port_available "4001"; then
  print_requirement_result "4" "OK" "Volume $VOL sadrži .txt fajlove, kontejner $CONT3 postoji, aktivan je, koristi volume i aplikacija je dostupna na portu 4001."
else
  print_requirement_result "4" "NIJE OK" "Volume ne sadrži očekivane .txt fajlove ili $CONT3 ne postoji, nije aktivan, ne koristi volume ili aplikacija nije dostupna na portu 4001."
fi

# --------------------------------------
# Zahtev 5
# MySQL baza radi + kontejner baze je aktivan
# --------------------------------------

if docker container inspect "$MYSQL_CONT" > /dev/null 2>&1 \
  && is_container_running "$MYSQL_CONT" \
  && docker exec "$MYSQL_CONT" mysqladmin ping -uroot -ppass --silent > /dev/null 2>&1 \
  && docker exec "$MYSQL_CONT" mysql -uroot -ppass -e "SHOW DATABASES;" 2>/dev/null | grep -q "feedback_db"; then
  print_requirement_result "5" "OK" "MySQL kontejner $MYSQL_CONT je aktivan, baza radi i feedback_db postoji."
else
  print_requirement_result "5" "NIJE OK" "MySQL kontejner ne postoji, nije aktivan, baza ne odgovara ili feedback_db nije pronađena."
fi

# --------------------------------------
# Zahtev 6
# Log fajl postoji u MySQL kontejneru
# --------------------------------------

if docker container inspect "$MYSQL_CONT" > /dev/null 2>&1 \
  && docker exec "$MYSQL_CONT" test -f /tmp/provera_baze.log; then
  print_requirement_result "6" "OK" "Log fajl /tmp/provera_baze.log postoji u MySQL kontejneru."
else
  print_requirement_result "6" "NIJE OK" "Log fajl /tmp/provera_baze.log ne postoji u MySQL kontejneru."
fi

# --------------------------------------
# Zahtev 7
# Mreža postoji + MySQL kontejner je dodat u mrežu
# --------------------------------------

if docker network inspect "$NET" > /dev/null 2>&1 \
  && is_container_in_network "$MYSQL_CONT" "$NET"; then
  print_requirement_result "7" "OK" "Mreža $NET postoji i MySQL kontejner $MYSQL_CONT je dodat u mrežu."
else
  print_requirement_result "7" "NIJE OK" "Mreža $NET ne postoji ili MySQL kontejner nije dodat u mrežu."
fi

# --------------------------------------
# Zahtev 8
# img:v2 postoji
# --------------------------------------

if docker image inspect "$IMG2" > /dev/null 2>&1; then
  print_requirement_result "8" "OK" "Image $IMG2 je kreiran."
else
  print_requirement_result "8" "NIJE OK" "Image $IMG2 nije kreiran."
fi

# --------------------------------------
# Zahtev 9
# baza1 postoji, aktivan je, koristi volume i mrežu, radi na 5000
# --------------------------------------

if docker container inspect "$APP_DB_CONT" > /dev/null 2>&1 \
  && is_container_running "$APP_DB_CONT" \
  && is_container_using_volume "$APP_DB_CONT" "$VOL" \
  && is_container_in_network "$APP_DB_CONT" "$NET" \
  && is_port_available "5000"; then
  print_requirement_result "9" "OK" "Kontejner $APP_DB_CONT postoji, aktivan je, koristi volume $VOL, povezan je na mrežu $NET i aplikacija radi na portu 5000."
else
  print_requirement_result "9" "NIJE OK" "$APP_DB_CONT ne postoji, nije aktivan, ne koristi volume, nije u mreži ili aplikacija nije dostupna na portu 5000."
fi

# --------------------------------------
# Zahtev 10
# /api/feedback radi i count je veći od 0
# --------------------------------------

API_JSON="api-feedback-${PREFIX}.json"
API_STATUS=$(curl -s --max-time 5 -o "$API_JSON" -w "%{http_code}" "http://localhost:5000/api/feedback")

API_COUNT=$(grep -o '"count":[0-9]*' "$API_JSON" 2>/dev/null | head -n 1 | cut -d ':' -f 2)

if [ "$API_STATUS" = "200" ] && [ -n "$API_COUNT" ] && [ "$API_COUNT" -gt 0 ]; then
  print_requirement_result "10" "OK" "/api/feedback ruta radi i count je veći od 0. Count: $API_COUNT."
else
  print_requirement_result "10" "NIJE OK" "/api/feedback ruta ne radi, ne vraća status 200 ili count nije veći od 0."
fi

# --------------------------------------
# Ukupan broj uspešnih zahteva
# --------------------------------------

echo ""
echo "======================================"
echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: $OK_COUNT/$TOTAL_REQUIREMENTS"
echo "======================================"

echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: $OK_COUNT/$TOTAL_REQUIREMENTS" >> "$REPORT"
echo "======================================" >> "$REPORT"

echo "" >> "$SUMMARY_FILE"
echo "======================================" >> "$SUMMARY_FILE"
echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: $OK_COUNT/$TOTAL_REQUIREMENTS" >> "$SUMMARY_FILE"
echo "======================================" >> "$SUMMARY_FILE"

echo ""
echo "Sumarna provera je sačuvana u: $SUMMARY_FILE"
echo "Sumarna provera je sačuvana u: $SUMMARY_FILE" >> "$REPORT"

# --------------------------------------
# Kreiranje ZIP arhive sa dokazima
# --------------------------------------

echo ""
echo "======================================"
echo "KREIRANJE ZIP ARHIVE SA DOKAZIMA"
echo "======================================"

echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "KREIRANJE ZIP ARHIVE SA DOKAZIMA" >> "$REPORT"
echo "======================================" >> "$REPORT"

ARCHIVE_DIR="dokazi-${PREFIX}"
ZIP_FILE="dokazi-${PREFIX}.zip"

rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR/feedback-fajlovi"

# Kopiranje Dockerfile-a
DOCKERFILE_PATH=$(find . -maxdepth 1 -type f -iname "dockerfile" | head -n 1)

if [ -n "$DOCKERFILE_PATH" ]; then
  cp "$DOCKERFILE_PATH" "$ARCHIVE_DIR/Dockerfile"
  echo "[OK] Dockerfile je dodat u arhivu iz fajla: $DOCKERFILE_PATH"
  echo "[OK] Dockerfile je dodat u arhivu iz fajla: $DOCKERFILE_PATH" >> "$REPORT"
else
  echo "[UPOZORENJE] Dockerfile nije pronađen u trenutnom direktorijumu."
  echo "[UPOZORENJE] Dockerfile nije pronađen u trenutnom direktorijumu." >> "$REPORT"
fi

# Kopiranje db.js fajla
if [ -f "db.js" ]; then
  cp db.js "$ARCHIVE_DIR/db.js"
  echo "[OK] db.js je dodat u arhivu."
  echo "[OK] db.js je dodat u arhivu." >> "$REPORT"
elif [ -f "app/db.js" ]; then
  cp app/db.js "$ARCHIVE_DIR/db.js"
  echo "[OK] app/db.js je dodat u arhivu kao db.js."
  echo "[OK] app/db.js je dodat u arhivu kao db.js." >> "$REPORT"
else
  echo "[UPOZORENJE] db.js nije pronađen u trenutnom direktorijumu niti u app/ folderu."
  echo "[UPOZORENJE] db.js nije pronađen u trenutnom direktorijumu niti u app/ folderu." >> "$REPORT"
fi

# Kopiranje .txt fajlova iz volume-a
if docker volume inspect "$VOL" > /dev/null 2>&1; then
  MOUNTPOINT=$(docker volume inspect "$VOL" --format '{{ .Mountpoint }}')

  if [ -d "$MOUNTPOINT" ]; then
    TXT_COUNT=$(sudo find "$MOUNTPOINT" -type f -name "*.txt" | wc -l)

    if [ "$TXT_COUNT" -gt 0 ]; then
      sudo find "$MOUNTPOINT" -type f -name "*.txt" -exec cp {} "$ARCHIVE_DIR/feedback-fajlovi/" \;
      sudo chown -R "$USER":"$USER" "$ARCHIVE_DIR/feedback-fajlovi" 2>/dev/null

      echo "[OK] Dodato je $TXT_COUNT .txt fajlova iz volume-a u arhivu."
      echo "[OK] Dodato je $TXT_COUNT .txt fajlova iz volume-a u arhivu." >> "$REPORT"
    else
      echo "[UPOZORENJE] U volume-u nisu pronađeni .txt fajlovi."
      echo "[UPOZORENJE] U volume-u nisu pronađeni .txt fajlovi." >> "$REPORT"
    fi
  else
    echo "[UPOZORENJE] Mountpoint ne postoji kao direktorijum: $MOUNTPOINT"
    echo "[UPOZORENJE] Mountpoint ne postoji kao direktorijum: $MOUNTPOINT" >> "$REPORT"
  fi
else
  echo "[UPOZORENJE] Volume $VOL ne postoji, .txt fajlovi nisu dodati u arhivu."
  echo "[UPOZORENJE] Volume $VOL ne postoji, .txt fajlovi nisu dodati u arhivu." >> "$REPORT"
fi

# Opciono: dodavanje izveštaja u arhivu
if [ -f "$REPORT" ]; then
  cp "$REPORT" "$ARCHIVE_DIR/"
fi

if [ -f "$SUMMARY_FILE" ]; then
  cp "$SUMMARY_FILE" "$ARCHIVE_DIR/"
fi

if [ -f "provera-baze-${PREFIX}.txt" ]; then
  cp "provera-baze-${PREFIX}.txt" "$ARCHIVE_DIR/"
fi

if [ -f "mysql-log-${PREFIX}.txt" ]; then
  cp "mysql-log-${PREFIX}.txt" "$ARCHIVE_DIR/"
fi

if [ -f "api-feedback-${PREFIX}.json" ]; then
  cp "api-feedback-${PREFIX}.json" "$ARCHIVE_DIR/"
fi

# Kreiranje zip fajla
if command -v zip > /dev/null 2>&1; then
  zip -r "$ZIP_FILE" "$ARCHIVE_DIR" > /dev/null

  echo "[OK] Kreirana je ZIP arhiva: $ZIP_FILE"
  echo "[OK] Kreirana je ZIP arhiva: $ZIP_FILE" >> "$REPORT"
else
  echo "[UPOZORENJE] Komanda zip nije instalirana. Instaliraj je komandom: sudo apt install zip"
  echo "[UPOZORENJE] Komanda zip nije instalirana. Instaliraj je komandom: sudo apt install zip" >> "$REPORT"
fi

echo ""
echo "ZIP arhiva: $ZIP_FILE"
echo "Folder sa dokazima: $ARCHIVE_DIR"