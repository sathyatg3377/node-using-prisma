#!/bin/bash
set -e

#######################################################
# FoD Configuration
#######################################################

# Example:
# Application  = Node-Prisma
# Microservice = Node-Prisma-API
# Release      = Release-1
#
# Configure these as AWS CodeBuild environment variables:
# FOD_APPLICATION
# FOD_MICROSERVICE
# FOD_RELEASE

echo "===== Fortify FoD Configuration ====="

echo "Application  : $FOD_APPLICATION"
echo "Microservice : $FOD_MICROSERVICE"
echo "Release      : $FOD_RELEASE"

# Construct:
# Application:Microservice:Release

FOD_TARGET="${FOD_APPLICATION}:${FOD_MICROSERVICE}:${FOD_RELEASE}"

echo "FoD Target   : $FOD_TARGET"


#######################################################
# Install Fortify CLI
#######################################################

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


#######################################################
# Download ScanCentral Client from Public GitHub Repo
#######################################################

echo "===== Downloading ScanCentral Client ====="

curl -L \
https://github.com/sathyatg3377/Fortify_ScanCentral_Client_Latest_x64/archive/refs/heads/main.zip \
-o scancentral.zip


echo "===== Extracting ScanCentral Client ====="

unzip -q scancentral.zip


SC_DIR=$(find . \
-maxdepth 1 \
-type d \
-name "Fortify_ScanCentral_Client_Latest_x64-*" \
| head -1)


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
# Package Application / Microservice
#######################################################

echo "===== Packaging Source ====="

scancentral package \
  -o package.zip


echo "===== Package Created ====="

ls -lh package.zip


#######################################################
# Start FoD SAST Scan
#######################################################

echo "========================================="
echo " Starting Fortify FoD SAST Scan"
echo "========================================="

echo "Application  : $FOD_APPLICATION"
echo "Microservice : $FOD_MICROSERVICE"
echo "Release      : $FOD_RELEASE"

fcli fod sast-scan start \
  --release "$FOD_TARGET" \
  --file package.zip \
  --store scan


#######################################################
# Wait for Scan
#######################################################

echo "===== Waiting for Scan ====="

fcli fod sast-scan wait-for ::scan::


#######################################################
# Policy / Quality Gate Check
#######################################################

echo "===== Policy Check ====="

fcli fod action run check-policy \
  --release "$FOD_TARGET"


#######################################################
# Logout
#######################################################

echo "===== Logout ====="

fcli fod session logout


#######################################################
# Completed
#######################################################

echo ""
echo "========================================="
echo " Fortify FoD Scan Completed"
echo "========================================="

echo "Application  : $FOD_APPLICATION"
echo "Microservice : $FOD_MICROSERVICE"
echo "Release      : $FOD_RELEASE"

echo "========================================="
