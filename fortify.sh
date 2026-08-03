#!/bin/bash
set -e

#######################################################
# FoD Configuration
#######################################################

# Configure these as AWS CodeBuild environment variables:
#
# FOD_URL
# FOD_USER
# FOD_PASSWORD
# FOD_TENANT
# FOD_APPLICATION
# FOD_MICROSERVICE
# FOD_RELEASE
#
# Example:
#
# Application  = Node-Prisma
# Microservice = Node-Prisma-API
# Release      = Release-1

echo "========================================="
echo " Fortify FoD Configuration"
echo "========================================="

echo "Application  : $FOD_APPLICATION"
echo "Microservice : $FOD_MICROSERVICE"
echo "Release      : $FOD_RELEASE"


#######################################################
# Construct FoD Target
#######################################################

# Format:
#
# Application:Microservice:Release

FOD_TARGET="${FOD_APPLICATION}:${FOD_MICROSERVICE}:${FOD_RELEASE}"

echo "FoD Target   : $FOD_TARGET"


#######################################################
# Install Fortify CLI
#######################################################

echo ""
echo "===== Installing Fortify CLI ====="

curl -L \
https://github.com/fortify/fcli/releases/latest/download/fcli-linux.tgz \
-o fcli.tgz

mkdir -p fcli

tar -xzf fcli.tgz -C fcli

chmod +x fcli/fcli

export PATH=$PWD/fcli:$PATH


echo "===== Fortify CLI Version ====="

fcli --version


#######################################################
# Download ScanCentral Client
#######################################################

echo ""
echo "===== Downloading ScanCentral Client ====="

curl -L \
https://github.com/sathyatg3377/Fortify_ScanCentral_Client_Latest_x64/archive/refs/heads/main.zip \
-o scancentral.zip


#######################################################
# Extract ScanCentral Client
#######################################################

echo "===== Extracting ScanCentral Client ====="

unzip -q scancentral.zip


SC_DIR=$(find . \
-maxdepth 1 \
-type d \
-name "Fortify_ScanCentral_Client_Latest_x64-*" \
| head -1)


echo "ScanCentral Directory: $SC_DIR"


if [ -z "$SC_DIR" ]; then

    echo "ERROR: ScanCentral Client directory not found."

    exit 1

fi


chmod -R +x "$SC_DIR/bin"

export PATH="$SC_DIR/bin:$PATH"


echo "===== ScanCentral Version ====="

scancentral --version


#######################################################
# Login to FoD
#######################################################

echo ""
echo "===== Login to FoD ====="

fcli fod session login \
  --url "$FOD_URL" \
  -u "$FOD_USER" \
  -p "$FOD_PASSWORD" \
  -t "$FOD_TENANT"


#######################################################
# Build NodeJS
#######################################################

echo ""
echo "===== Installing Node Modules ====="

npm install


#######################################################
# Package Application / Microservice
#######################################################

echo ""
echo "===== Packaging Source ====="

scancentral package \
  -o package.zip


echo "===== Package Created ====="

ls -lh package.zip


#######################################################
# Start FoD SAST Scan
#######################################################

echo ""
echo "========================================="
echo " Starting Fortify FoD SAST Scan"
echo "========================================="

echo "Application  : $FOD_APPLICATION"
echo "Microservice : $FOD_MICROSERVICE"
echo "Release      : $FOD_RELEASE"
echo "FoD Target   : $FOD_TARGET"

echo "========================================="


fcli fod sast-scan start \
  --release "$FOD_TARGET" \
  --file package.zip \
  --store scan


#######################################################
# Wait for SAST Scan
#######################################################

echo ""
echo "===== Waiting for SAST Scan ====="

fcli fod sast-scan wait-for \
  ::scan::


echo ""
echo "========================================="
echo " SAST Scan Completed"
echo "========================================="


#######################################################
# Create Reports Directory
#######################################################

echo ""
echo "===== Creating Reports Directory ====="

mkdir -p reports


#######################################################
# Generate Unique Report Timestamp
#######################################################

REPORT_TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "Report Timestamp: $REPORT_TIMESTAMP"


#######################################################
# Static Summary Report
#######################################################

echo ""
echo "========================================="
echo " Creating Static Summary Report"
echo "========================================="

SUMMARY_REPORT_NAME="Static-Summary-${FOD_RELEASE}-${REPORT_TIMESTAMP}"


fcli fod report create \
  "$SUMMARY_REPORT_NAME" \
  --release "$FOD_TARGET" \
  --template -1 \
  --format pdf \
  --store summaryReport


#######################################################
# Wait for Static Summary Report
#######################################################

echo "===== Waiting for Static Summary Report ====="

fcli fod report wait-for \
  ::summaryReport:: \
  --timeout 30m


#######################################################
# Download Static Summary Report
#######################################################

echo "===== Downloading Static Summary Report ====="

fcli fod report download \
  ::summaryReport:: \
  --file reports/Static_Summary.pdf


echo "Static Summary Report downloaded successfully."


#######################################################
# Static Issue Detail Report
#######################################################

echo ""
echo "========================================="
echo " Creating Static Issue Detail Report"
echo "========================================="

ISSUE_REPORT_NAME="Static-Issue-Detail-${FOD_RELEASE}-${REPORT_TIMESTAMP}"


fcli fod report create \
  "$ISSUE_REPORT_NAME" \
  --release "$FOD_TARGET" \
  --template -2 \
  --format pdf \
  --store issueReport


#######################################################
# Wait for Static Issue Detail Report
#######################################################

echo "===== Waiting for Static Issue Detail Report ====="

fcli fod report wait-for \
  ::issueReport:: \
  --timeout 30m


#######################################################
# Download Static Issue Detail Report
#######################################################

echo "===== Downloading Static Issue Detail Report ====="

fcli fod report download \
  ::issueReport:: \
  --file reports/Static_Issue_Detail.pdf


echo "Static Issue Detail Report downloaded successfully."


#######################################################
# Static Comprehensive Report
#######################################################

echo ""
echo "========================================="
echo " Creating Static Comprehensive Report"
echo "========================================="

COMPREHENSIVE_REPORT_NAME="Static-Comprehensive-${FOD_RELEASE}-${REPORT_TIMESTAMP}"


fcli fod report create \
  "$COMPREHENSIVE_REPORT_NAME" \
  --release "$FOD_TARGET" \
  --template -4 \
  --format pdf \
  --store comprehensiveReport


#######################################################
# Wait for Static Comprehensive Report
#######################################################

echo "===== Waiting for Static Comprehensive Report ====="

fcli fod report wait-for \
  ::comprehensiveReport:: \
  --timeout 30m


#######################################################
# Download Static Comprehensive Report
#######################################################

echo "===== Downloading Static Comprehensive Report ====="

fcli fod report download \
  ::comprehensiveReport:: \
  --file reports/Static_Comprehensive.pdf


echo "Static Comprehensive Report downloaded successfully."


#######################################################
# Display Generated Reports
#######################################################

echo ""
echo "========================================="
echo " Generated FoD Reports"
echo "========================================="

ls -lh reports/


#######################################################
# Policy / Quality Gate Check
#######################################################

echo ""
echo "========================================="
echo " Running Policy / Quality Gate Check"
echo "========================================="

fcli fod action run check-policy \
  --release "$FOD_TARGET"


echo ""
echo "========================================="
echo " Policy Check Completed Successfully"
echo "========================================="


#######################################################
# Logout
#######################################################

echo ""
echo "===== Logout ====="

fcli fod session logout


#######################################################
# Completed
#######################################################

echo ""
echo "========================================="
echo " Fortify FoD Scan Completed Successfully"
echo "========================================="

echo ""
echo "Application  : $FOD_APPLICATION"
echo "Microservice : $FOD_MICROSERVICE"
echo "Release      : $FOD_RELEASE"

echo ""
echo "Generated Reports:"
echo "-----------------------------------------"

ls -lh reports/

echo ""
echo "========================================="
echo " Completed"
echo "========================================="
