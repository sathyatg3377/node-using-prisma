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

fcli fod sast-scan start --release "$FOD_RELEASE" --file package.zip --store scan

echo "===== Waiting for Scan ====="

fcli fod sast-scan wait-for ::scan::

#######################################################
# Create Reports Folder
#######################################################

mkdir -p reports

#######################################################
# Download FPR
#######################################################
echo "===== Downloading FPR ====="

fcli fod sast-scan download \
    ::scan:: \
    -f reports/Fortify_Report.fpr

echo "FPR downloaded successfully."

#######################################################
# Save Scan Summary
#######################################################

echo "===== Saving Scan Summary ====="

fcli fod sast-scan get \
    ::scan:: \
    -o json > reports/ScanSummary.json

#######################################################
# Generate Executive Summary
#######################################################

echo "===== Generating Executive Summary ====="

# TODO:
# Replace EXECUTIVE_TEMPLATE_ID with your FoD Report Template ID
# Call POST /api/v3/reports
# Poll until completed
# Download report to:
# reports/Executive_Summary.pdf

#######################################################
# Generate Developer Report
#######################################################

echo "===== Generating Developer Report ====="

# TODO:
# Replace DEVELOPER_TEMPLATE_ID with your FoD Report Template ID
# Call POST /api/v3/reports
# Download report to:
# reports/Developer_Report.pdf

#######################################################
# Generate Vulnerability Report
#######################################################

echo "===== Generating Vulnerability Report ====="

# TODO:
# Replace VULNERABILITY_TEMPLATE_ID with your FoD Report Template ID
# Call POST /api/v3/reports
# Download report to:
# reports/Vulnerability_Report.pdf

#######################################################
# Policy Check
#######################################################

echo "===== Running Policy Check ====="

fcli fod action run check-policy \
    --release "$FOD_RELEASE"

#######################################################
# Logout
#######################################################

echo "===== Logout ====="

fcli fod session logout

#######################################################
# Generated Files
#######################################################

echo ""
echo "========================================="
echo " Fortify Scan Completed Successfully"
echo "========================================="

echo ""
echo "Generated Reports:"

ls -lh reports
