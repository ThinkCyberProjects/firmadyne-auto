#!/bin/bash

# Ensure run as root
if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root. Use: sudo bash $0"
    exit 1
fi


# === Banner ===
if ! command -v figlet &>/dev/null; then
    echo "[*] Installing figlet..."
    apt update && apt install -y figlet
fi
figlet "IoT Exploitation for RTX"
sleep 1
# === Configuration ===
FIRMADYNE_DIR="/opt/firmadyne"
TOOLS_DIR="$FIRMADYNE_DIR/tools"
LOG_DIR="$FIRMADYNE_DIR/logs"
DB_USER="firmadyne"
DB_NAME="firmware"
DB_PASS="firmadyne"

# === Setup folders ===


mkdir -p "$FIRMADYNE_DIR" "$LOG_DIR"
chown -R $USER:$USER "$FIRMADYNE_DIR"

echo "[*] Installing required packages..."
apt install -y busybox-static fakeroot git dmsetup kpartx netcat-openbsd snmp util-linux vlan \
    nmap python3-psycopg2 python3-pip python3-magic gcc-mips-linux-gnu\
    qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils postgresql wget unzip expect \
    gcc-mipsel-linux-gnu g++-mipsel-linux-gnu qemu-user-static

echo "[*] Cloning Firmadyne..."
sudo rm -rf "$FIRMADYNE_DIR"

git clone --recursive https://github.com/firmadyne/firmadyne.git "$FIRMADYNE_DIR"

echo "[*] Cloning and installing Binwalk..."
git clone https://github.com/ReFirmLabs/binwalk.git "$FIRMADYNE_DIR/binwalk"
cd "$FIRMADYNE_DIR/binwalk/dependencies"
bash ubuntu.sh
cd ..


echo "[*] Creating virtualenv..."
cd "$FIRMADYNE_DIR"
python3 -m venv tools
source tools/bin/activate
pip install --upgrade pip
pip install psycopg2-binary six git+https://github.com/sviehb/jefferson \
    git+https://github.com/ahupp/python-magic binwalk

echo "[*] Setting up PostgreSQL..."
service postgresql restart || true
sudo -u postgres psql -c "ALTER DATABASE template1 REFRESH COLLATION VERSION;" || true
sudo -u postgres psql -c "ALTER DATABASE postgres REFRESH COLLATION VERSION;" || true
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" || true
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" || true
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres createdb -O $DB_USER $DB_NAME
sudo -u postgres psql -d $DB_NAME < "$FIRMADYNE_DIR/database/schema"

echo "[*] Downloading firmware support files..."
cd "$FIRMADYNE_DIR"
bash download.sh

echo "[*] Installing uml-utilities..."
wget -P /tmp http://ftp.us.debian.org/debian/pool/main/u/uml-utilities/uml-utilities_20070815.4-2.1_amd64.deb
dpkg -i /tmp/uml-utilities_*.deb || apt --fix-broken install -y
rm /tmp/uml-utilities_*.deb

echo "[*] Setting firmadyne.config..."
sed -i "s|^#FIRMWARE_DIR=.*|FIRMWARE_DIR=$FIRMADYNE_DIR|" "$FIRMADYNE_DIR/firmadyne.config"

# === Generate Firmadyne.sh ===
cat <<EOF > "$FIRMADYNE_DIR/Firmadyne.sh"
#!/bin/bash

if [ "\$(whoami)" != "root" ]; then
    echo "Must run with sudo. Exiting..."
    exit 1
fi

# === BANNER ===
if ! command -v figlet &>/dev/null; then
    apt install -y figlet
fi
figlet "IoT Exploitation for RTX"
sleep 1
service postgresql restart || true
DB_USER="firmadyne"
DB_NAME="firmware"
DB_PASS="firmadyne"
LOG_DIR="/opt/firmadyne/logs"

echo "[*] Flushing Firmadyne database..."
export PGPASSWORD=\$DB_PASS
sudo -u postgres psql -d \$DB_NAME -c "DELETE FROM object_to_image;"
sudo -u postgres psql -d \$DB_NAME -c "DELETE FROM image;"
sudo -u postgres psql -d \$DB_NAME -c "ALTER SEQUENCE image_id_seq RESTART WITH 1;"
echo "[✔] Database reset complete."

echo "[*] Cleaning old images and scratch files..."
sudo rm -rf /opt/firmadyne/images/*
sudo rm -rf /opt/firmadyne/scratch/*
echo "[✔] File system cleanup complete."


echo "[*] Checking dependencies..."
for cmd in python3 qemu-system-mips binwalk psql; do
    if ! command -v \$cmd &>/dev/null; then
        echo "[!] Missing: \$cmd"
        exit 1
    fi
done

source /opt/firmadyne/tools/bin/activate || { echo '[!] Python env missing.'; exit 1; }

read -p "Enter full path to firmware file: " FW_PATH
read -p "Enter the firmware vendor: " VENDOR
FW_PATH="\${FW_PATH%\"}"; FW_PATH="\${FW_PATH#\"}"
FW_PATH="\${FW_PATH%\'}"; FW_PATH="\${FW_PATH#\'}"

if [[ ! -f "\$FW_PATH" ]]; then
    echo "[!] Firmware not found: \$FW_PATH"
    exit 1
fi

cd /opt/firmadyne
echo "[*] Extracting firmware..."
EXTRACT_OUTPUT=\$(sudo python3 ./sources/extractor/extractor.py -b \$VENDOR -sql 127.0.0.1 -np -nk "\$FW_PATH" images 2>&1)
TAG_ID=\$(echo "\$EXTRACT_OUTPUT" | grep "Database Image ID" | awk '{print \$NF}')
if [[ -z "\$TAG_ID" ]]; then
    echo "[!] Extraction failed. Output:"
    echo "\$EXTRACT_OUTPUT"
    exit 1
fi

echo "[*] Using tag ID: \$TAG_ID"

TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
mkdir -p "\$LOG_DIR"
LOG_FILE="\$LOG_DIR/firmadyne_run_id\${TAG_ID}_\$TIMESTAMP.log"
exec > >(tee -a "\$LOG_FILE") 2>&1

echo "[*] Detecting architecture..."
sudo bash scripts/getArch.sh images/\$TAG_ID.tar.gz

export PGPASSWORD=\$DB_PASS

echo "[*] Inserting into database..."
python3 scripts/tar2db.py -i \$TAG_ID -f images/\${TAG_ID}.tar.gz

echo "[*] Creating emulation image..."
sudo bash scripts/makeImage.sh \$TAG_ID

echo "[*] Inferring network..."
set +e
sudo bash scripts/inferNetwork.sh \$TAG_ID
set -e

echo "[*] Launching in QEMU..."
sudo bash scratch/\$TAG_ID/run.sh
EOF

chmod +x "$FIRMADYNE_DIR/Firmadyne.sh"

echo "[✔] Setup complete."
echo "    To run: sudo bash /opt/firmadyne/Firmadyne.sh"
