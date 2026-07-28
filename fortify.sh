#!/bin/bash
set -e

echo "===== Installing Fortify CLI ====="

curl -L https://github.com/fortify/fcli/releases/latest/download/fcli-linux.tgz -o fcli.tgz

mkdir -p fcli
tar -xzf fcli.tgz -C fcli
chmod +x fcli/fcli

export PATH=$PWD/fcli:$PATH

echo "Fortify CLI Version:"
fcli --version

#######################################################
# Download ScanCentral Client from Public GitHub Repo #
#######################################################

echo "===== Downloading ScanCentral Client ====="

curl -L \
https://github.com/sathyatg3377/Fortify_ScanCentral_Client_Latest_x64/archive/refs/heads/main.zip \
-o scancentral.zip

echo "===== Extracting ScanCentral Client ====="

unzip -q scancentral.zip

SC_DIR=$(find . -maxdepth 1 -type d -name "Fortify_ScanCentral_Client_Latest_x64-*")

echo "ScanCentral Directory: $SC_DIR"

chmod -R +x "$SC_DIR/bin"

export PATH="$SC_DIR/bin:$PATH"

echo "===== ScanCentral Version ====="

scancentral --version

#######################################################
# Login to FoD
#######################################################

echo "===== Login to FoD ====="

fcli fod session login \
  --url "$FOD_URL" \
  -u "$FOD_USER" \
  -p "$FOD_PASSWORD" \
  -t "$FOD_TENANT"

#######################################################
# Build NodeJS
#######################################################

echo "===== Installing Node Modules ====="

npm install

#######################################################
# Package
#######################################################

echo "===== Packaging Source ====="

scancentral package -o package.zip

#######################################################
# Start Scan
#######################################################

echo "===== Starting Scan ====="

fcli fod sast-scan start \
    --release "$FOD_RELEASE" \
    --file package.zip

echo "===== Waiting for Scan ====="

fcli fod sast-scan wait-for ::last::

echo "===== Policy Check ====="

fcli fod action run check-policy

echo "===== Logout ====="

fcli fod session logout
