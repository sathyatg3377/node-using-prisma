#!/bin/bash
set -e

echo "===== Installing Fortify CLI ====="

curl -L \
  https://github.com/fortify/fcli/releases/latest/download/fcli-linux.tgz \
  -o fcli.tgz

mkdir -p fcli
tar -xzf fcli.tgz -C fcli

chmod +x fcli/fcli
export PATH=$PWD/fcli:$PATH

echo "Fortify CLI Version:"
fcli --version

echo "===== Downloading ScanCentral Client ====="

curl -L \
  -u "$FOD_USER:$FOD_PASSWORD" \
  -o Fortify_ScanCentral_Client.zip \
  "https://ams.fortify.com/Tools/ScanCentral/Fortify_ScanCentral_Client_Latest_x64.zip"

echo "===== Verifying Download ====="

ls -lh Fortify_ScanCentral_Client.zip
file Fortify_ScanCentral_Client.zip

if ! unzip -t Fortify_ScanCentral_Client.zip >/dev/null 2>&1; then
    echo "ERROR: Downloaded file is not a valid ZIP."
    echo "The FoD server most likely returned an HTML login page or an authentication error."
    echo ""
    echo "First 20 lines of the downloaded file:"
    head -20 Fortify_ScanCentral_Client.zip
    exit 1
fi

echo "===== Extracting ScanCentral Client ====="

mkdir -p scancentral
unzip -q Fortify_ScanCentral_Client.zip -d scancentral

find scancentral -type f -exec chmod +x {} \;

SCANCENTRAL_BIN=$(find scancentral -type f -name scancentral | head -1)

if [ -z "$SCANCENTRAL_BIN" ]; then
    echo "ERROR: ScanCentral executable not found."
    exit 1
fi

export PATH=$(dirname "$SCANCENTRAL_BIN"):$PATH

echo "ScanCentral Version:"
scancentral --version

echo "===== Login to FoD ====="

fcli fod session login \
  --url "$FOD_URL" \
  -u "$FOD_USER" \
  -p "$FOD_PASSWORD" \
  -t "$FOD_TENANT"

echo "===== Installing Node Dependencies ====="

npm install

echo "===== Packaging Source ====="

scancentral package -o package.zip

echo "===== Starting Scan ====="

fcli fod sast-scan start \
  --release "$FOD_RELEASE" \
  --file package.zip

echo "===== Waiting for Scan ====="

fcli fod sast-scan wait

echo "===== Policy Check ====="

fcli fod action run check-policy

echo "===== Logout ====="

fcli fod session logout
