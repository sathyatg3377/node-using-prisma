#!/bin/bash
set -e

echo "Installing Fortify CLI..."

curl -L https://github.com/fortify/fcli/releases/latest/download/fcli-linux.tgz -o fcli.tgz

mkdir -p fcli
tar -xzf fcli.tgz -C fcli

chmod +x fcli/fcli

export PATH=$PWD/fcli:$PATH

echo "Fortify CLI Version:"
fcli --version

echo "Logging in..."

fcli fod session login \
  --url "$FOD_URL" \
  -u "$FOD_USER" \
  -p "$FOD_PASSWORD" \
  -t "$FOD_TENANT"

echo "Installing Node.js dependencies..."

npm install

echo "Packaging Source..."

scancentral package -o package.zip

echo "Starting Scan..."

fcli fod sast-scan start \
  --release "$FOD_RELEASE" \
  --file package.zip

echo "Waiting for Scan..."

fcli fod sast-scan wait

echo "Checking Policy..."

fcli fod action run check-policy

echo "Logout..."

fcli fod session logout
