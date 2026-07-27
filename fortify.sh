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

echo "Fortify CLI Version"
fcli --version

echo "===== Downloading ScanCentral Client ====="

curl -L \
-u "$FOD_USER:$FOD_PASSWORD" \
https://ams.fortify.com/Tools/ScanCentral/Fortify_ScanCentral_Client_Latest_x64.zip \
-o Fortify_ScanCentral_Client.zip

unzip -q Fortify_ScanCentral_Client.zip -d scancentral

chmod +x scancentral/scancentral
chmod +x scancentral/packagescanner
chmod +x scancentral/pwtool

export PATH=$PWD/scancentral:$PATH

echo "ScanCentral Version"
scancentral --version

echo "===== Login to FoD ====="

fcli fod session login \
  --url "$FOD_URL" \
  -u "$FOD_USER" \
  -p "$FOD_PASSWORD" \
  -t "$FOD_TENANT"

echo "===== Node Build ====="

npm install

echo "===== Package ====="

scancentral package -o package.zip

echo "===== Start Scan ====="

fcli fod sast-scan start \
  --release "$FOD_RELEASE" \
  --file package.zip

echo "===== Wait ====="

fcli fod sast-scan wait

echo "===== Policy Check ====="

fcli fod action run check-policy

echo "===== Logout ====="

fcli fod session logout
