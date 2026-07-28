#!/bin/bash
###############################################################################
# OpenText Fortify on Demand CI/CD Script
# Version : 1.0
# Platform: AWS CodeBuild
# Author  : Sathya Narayanan
###############################################################################

set -euo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

REPORT_DIR="reports"
SC_VERSION="25.4.0"

mkdir -p "${REPORT_DIR}"

###############################################################################
# COLORS
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log(){
    echo -e "${GREEN}[$(date '+%F %T')]${NC} $1"
}

warn(){
    echo -e "${YELLOW}[$(date '+%F %T')] WARNING:${NC} $1"
}

error(){
    echo -e "${RED}[$(date '+%F %T')] ERROR:${NC} $1"
}

###############################################################################
# VALIDATE ENVIRONMENT VARIABLES
###############################################################################

required=(
FOD_URL
FOD_USER
FOD_PASSWORD
FOD_TENANT
FOD_APPLICATION
FOD_RELEASE
)

log "Validating environment variables..."

for var in "${required[@]}"
do
    if [ -z "${!var:-}" ]; then
        error "$var is not configured."
        exit 1
    fi
done

###############################################################################
# INSTALL FCLI
###############################################################################

log "Installing Fortify CLI..."

curl -L \
https://github.com/fortify/fcli/releases/download/v3.23.3/fcli-linux.tgz \
-o fcli.tgz

tar -xzf fcli.tgz

chmod +x fcli/fcli

export PATH=$PWD/fcli:$PATH

log "Fortify CLI Version"

fcli --version

###############################################################################
# DOWNLOAD SCANCENTRAL CLIENT
###############################################################################

log "Downloading ScanCentral Client..."

curl -L \
https://github.com/sathyatg3377/Fortify_ScanCentral_Client_Latest_x64/archive/refs/heads/main.zip \
-o scancentral.zip

unzip -q scancentral.zip

SC_DIR=$(find . -maxdepth 1 -type d -name "Fortify_ScanCentral_Client_Latest_x64-*")

if [ -z "$SC_DIR" ]; then
    error "Unable to locate ScanCentral Client."
    exit 1
fi

export PATH="$SC_DIR/bin:$PATH"

log "ScanCentral Version"

scancentral --version

###############################################################################
# LOGIN
###############################################################################

log "Logging into Fortify on Demand..."

fcli fod session login \
    --url "$FOD_URL" \
    -u "$FOD_USER" \
    -p "$FOD_PASSWORD" \
    -t "$FOD_TENANT"

###############################################################################
# VERIFY SESSION
###############################################################################

log "FoD Session"

fcli fod session list

###############################################################################
# CHECK APPLICATION
###############################################################################

log "Checking Application..."

if ! fcli fod app list -o json | grep -q "\"name\":\"${FOD_APPLICATION}\""
then
    warn "Application not found."

    log "Creating Application..."

    fcli fod app create \
        --name "$FOD_APPLICATION" \
        --description "Created from AWS CodeBuild"
else
    log "Application already exists."
fi

###############################################################################
# CHECK RELEASE
###############################################################################

log "Checking Release..."

if ! fcli fod release list -o json | grep -q "\"releaseName\":\"${FOD_RELEASE}\""
then
    warn "Release does not exist."

    log "Creating Release..."

    fcli fod release create \
        --application "$FOD_APPLICATION" \
        --name "$FOD_RELEASE"
else
    log "Release already exists."
fi

###############################################################################
# CONFIGURE SAST
###############################################################################

log "Checking SAST Configuration..."

if ! fcli fod sast-scan get-config \
    --release "$FOD_RELEASE" >/dev/null 2>&1
then

    log "Configuring SAST..."

    fcli fod sast-scan setup \
        --release "$FOD_RELEASE" \
        --technology JavaScript \
        --language-level ES2022

else

    log "SAST already configured."

fi

###############################################################################
# INSTALL NODE MODULES
###############################################################################

log "Installing Node Modules..."

npm ci

###############################################################################
# PACKAGE APPLICATION
###############################################################################

log "Packaging Application..."

scancentral package \
    -o package.zip

log "Package created successfully."

###############################################################################
# START SAST SCAN
###############################################################################

log "Starting SAST Scan..."

fcli fod sast-scan start \
    --release "$FOD_RELEASE" \
    --file package.zip \
    --store scan

SCAN_ID=$(fcli util variable contents scan --expr "{id}")

log "Scan Started Successfully"
log "Scan ID : ${SCAN_ID}"

###############################################################################
# WAIT FOR SCAN
###############################################################################

log "Waiting for Scan Completion..."

fcli fod sast-scan wait-for ::scan:: \
    --interval 30s \
    --timeout 2h

log "Scan Completed"

###############################################################################
# SCAN DETAILS
###############################################################################

log "Collecting Scan Details..."

fcli fod sast-scan get "$SCAN_ID" \
    -o json > ${REPORT_DIR}/ScanResult.json

log "Printing Scan Summary..."

fcli fod sast-scan get "$SCAN_ID"

###############################################################################
# DOWNLOAD FPR
###############################################################################

log "Downloading FPR..."

fcli fod sast-scan download \
    "$SCAN_ID" \
    --file ${REPORT_DIR}/Fortify_Report.fpr

###############################################################################
# DOWNLOAD LATEST FPR (BACKUP)
###############################################################################

log "Downloading Latest Scan Result..."

fcli fod sast-scan download-latest \
    --release "$FOD_RELEASE" \
    --file ${REPORT_DIR}/Latest_Report.fpr || true

###############################################################################
# EXPORT JSON SUMMARY
###############################################################################

log "Exporting JSON Summary..."

fcli fod sast-scan get "$SCAN_ID" \
    -o json > ${REPORT_DIR}/ScanSummary.json

###############################################################################
# POLICY CHECK
###############################################################################

log "Running Policy Check..."

fcli fod action run check-policy \
    --release "$FOD_RELEASE"

###############################################################################
# LIST VULNERABILITIES
###############################################################################

log "Getting Vulnerability Summary..."

fcli fod vuln list \
    --release "$FOD_RELEASE" \
    -o table || true

###############################################################################
# BUILD INFORMATION
###############################################################################

log "Creating Build Information..."

cat <<EOF > ${REPORT_DIR}/BuildInfo.txt

=========================================
OpenText Fortify on Demand Build Summary
=========================================

Application : ${FOD_APPLICATION}

Release     : ${FOD_RELEASE}

Scan ID     : ${SCAN_ID}

Build Date  : $(date)

=========================================

EOF

###############################################################################
# OPTIONAL PDF REPORT
###############################################################################

log "Attempting PDF Report Export..."

fcli fod report download \
    --release "$FOD_RELEASE" \
    --type "Vulnerability" \
    --output ${REPORT_DIR}/Vulnerability_Report.pdf || true

###############################################################################
# LOGOUT
###############################################################################

log "Logging out..."

fcli fod session logout

###############################################################################
# CLEANUP
###############################################################################

log "Cleaning temporary files..."

rm -rf package.zip
rm -rf scancentral.zip
rm -rf fcli.tgz

###############################################################################
# FINISHED
###############################################################################

log "==============================================="
log "Fortify Scan Completed Successfully"
log "==============================================="

log "Artifacts Generated"

ls -lh ${REPORT_DIR}

exit 0
