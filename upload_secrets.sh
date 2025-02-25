#!/bin/bash

# Exit on error
set -e

# Vault server and root token
VAULT_ADDR="http://<Vault-IP>:8200"
VAULT_TOKEN="<Root Token hsv.>"  # Your working root token
JSON_FILE="secrets.json"

# Verify Vault connectivity
echo "Checking Vault connectivity..."
curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/auth/token/lookup-self" | jq . || { echo "Error: Invalid Vault token or server unreachable"; exit 1; }

# Function to upload a secret via HTTP API
upload_secret() {
    local key="$1"
    echo "Processing $key..."
    if jq -e ".\"$key\".data != null" "$JSON_FILE" >/dev/null; then
        echo "Uploading $key to Vault via HTTP API..."
        # Extract the 'data' sub-object as a flat JSON payload
        PAYLOAD=$(jq -c ".\"$key\".data" "$JSON_FILE")
        curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
             -H "Content-Type: application/json" \
             -X POST \
             --data "{\"data\": $PAYLOAD}" \
             "$VAULT_ADDR/v1/secret/data/$key" || { echo "Failed to upload $key"; exit 1; }
        echo "Successfully uploaded $key"
    else
        echo "Skipping $key - 'data' field is null or missing"
    fi
}

# Upload all secrets
for key in aws-creds sonarqube snyk jfrog jira; do
    upload_secret "$key"
done

# Verify upload using vault CLI
echo "Verifying uploaded secrets..."
for key in aws-creds sonarqube snyk jfrog jira; do
    if jq -e ".\"$key\".data != null" "$JSON_FILE" >/dev/null; then
        vault kv get "secret/$key"
    fi
done