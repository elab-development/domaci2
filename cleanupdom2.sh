#!/bin/bash

PREFIX=$1

if [ -z "$PREFIX" ]; then
  echo "Upotreba: ./cleanup-domaci2.sh <studentski-prefiks>"
  echo "Primer: ./cleanup-domaci2.sh tn20185005"
  exit 1
fi

ZIP_FILE="dokazi-${PREFIX}.zip"

NET="${PREFIX}-network"
IMG1="${PREFIX}-img"
IMG2="${PREFIX}-img:v2"

echo "======================================"
echo "CLEANUP ZA: $PREFIX"
echo "======================================"
echo ""

# 1. Provera da li postoji ZIP arhiva

if [ ! -f "$ZIP_FILE" ]; then
  echo "[STOP] ZIP arhiva ne postoji: $ZIP_FILE"
  echo "Docker objekti neće biti obrisani."
  echo ""
  echo "Prvo pokreni skriptu za proveru koja kreira ZIP arhivu sa dokazima."
  exit 1
fi

echo "[OK] Pronađena ZIP arhiva: $ZIP_FILE"
echo "Nastavljam sa brisanjem Docker objekata..."
echo ""

# 2. Stopiranje svih kontejnera

echo "1. STOPIRANJE SVIH KONTEJNERA"
echo "--------------------------------------"

RUNNING_CONTAINERS=$(docker ps -q)

if [ -n "$RUNNING_CONTAINERS" ]; then
  docker stop $RUNNING_CONTAINERS
  echo "[OK] Svi aktivni kontejneri su stopirani."
else
  echo "[INFO] Nema aktivnih kontejnera."
fi

echo ""

# 3. Brisanje svih kontejnera

echo "2. BRISANJE SVIH KONTEJNERA"
echo "--------------------------------------"

ALL_CONTAINERS=$(docker ps -aq)

if [ -n "$ALL_CONTAINERS" ]; then
  docker rm $ALL_CONTAINERS
  echo "[OK] Svi kontejneri su obrisani."
else
  echo "[INFO] Nema kontejnera za brisanje."
fi

echo ""

# 4. Brisanje unused volume-a

echo "3. PRUNE SVIH UNUSED VOLUME-A"
echo "--------------------------------------"

docker volume prune -a

echo "[OK] Izvršen docker volume prune -a."
echo ""

# 5. Brisanje mreže po zadatom nazivu

echo "4. BRISANJE STUDENTSKE MREŽE"
echo "--------------------------------------"

if docker network inspect "$NET" > /dev/null 2>&1; then
  docker network rm "$NET" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "[OK] Obrisana mreža: $NET"
  else
    echo "[PROBLEM] Mreža nije obrisana: $NET"
  fi
else
  echo "[INFO] Mreža ne postoji: $NET"
fi

echo ""

# 6. Brisanje studentskih image-a

echo "5. BRISANJE STUDENTSKIH IMAGE-A"
echo "--------------------------------------"

for IMAGE in "$IMG2" "$IMG1"; do
  if docker image inspect "$IMAGE" > /dev/null 2>&1; then
    docker image rm "$IMAGE" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
      echo "[OK] Obrisan image: $IMAGE"
    else
      echo "[PROBLEM] Image nije obrisan: $IMAGE"
    fi
  else
    echo "[INFO] Image ne postoji: $IMAGE"
  fi
done

echo ""

# 7. Završna provera

echo "6. ZAVRŠNA PROVERA"
echo "--------------------------------------"

REMAINING_CONTAINERS=$(docker ps -aq)
REMAINING_VOLUMES=$(docker volume ls -q)

if [ -z "$REMAINING_CONTAINERS" ]; then
  echo "[OK] Nema preostalih kontejnera."
else
  echo "[UPOZORENJE] Još uvek postoje neki kontejneri:"
  docker ps -a
fi

echo ""

if [ -z "$REMAINING_VOLUMES" ]; then
  echo "[OK] Nema preostalih volume-a."
else
  echo "[INFO] Još uvek postoje neki volume-i:"
  docker volume ls
  echo "Napomena: docker volume prune briše samo volume-e koje ne koristi nijedan kontejner."
fi

echo ""

if docker network inspect "$NET" > /dev/null 2>&1; then
  echo "[UPOZORENJE] Studentska mreža još postoji: $NET"
else
  echo "[OK] Studentska mreža ne postoji: $NET"
fi

echo ""
echo "Cleanup završen."
echo "ZIP arhiva je sačuvana i nije obrisana: $ZIP_FILE"