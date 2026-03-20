#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy SnapPass to Azure Container Apps
#
# Prerequisites:
#   - Azure CLI (az) installed and logged in  (az login)
#   - An Azure subscription
#
# Usage:
#   export AZURE_RESOURCE_GROUP="rg-snappass-prod"
#   export AZURE_LOCATION="australiaeast"          # optional, overrides main.bicepparam
#   export SNAPPASS_SECRET_KEY="$(openssl rand -hex 32)"
#   chmod +x deploy.sh && ./deploy.sh
#
# What this script does:
#   1. Validates environment variables and Azure CLI login
#   2. Creates the resource group if it doesn't exist
#   3. Registers required Azure resource providers
#   4. Deploys the Bicep template (ACR, Redis, Identity, Container App)
#   5. Imports pinterest/snappass:latest from Docker Hub into ACR
#   6. Updates the Container App to use the ACR-hosted image
#   7. Prints the application URL
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
LOCATION="${AZURE_LOCATION:-australiaeast}"
BASE_NAME="${SNAPPASS_BASE_NAME:-snappass}"
DOCKER_IMAGE="pinterest/snappass:latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/infra"

# ---------------------------------------------------------------------------
# Step 1: Validate prerequisites
# ---------------------------------------------------------------------------
log "Validating prerequisites..."

if [[ -z "${RESOURCE_GROUP}" ]]; then
  error "AZURE_RESOURCE_GROUP is not set.\n  Run: export AZURE_RESOURCE_GROUP=rg-snappass-prod"
fi

if ! command -v az &>/dev/null; then
  error "Azure CLI (az) is not installed. See https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
fi

if ! az account show &>/dev/null; then
  error "Not logged in to Azure CLI. Run: az login"
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
success "Using subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"

# Generate a Flask secret key if not provided
if [[ -z "${SNAPPASS_SECRET_KEY:-}" ]]; then
  warn "SNAPPASS_SECRET_KEY not set — generating a random key."
  warn "Save this key somewhere secure if you need sessions to survive redeployments."
  if command -v openssl &>/dev/null; then
    export SNAPPASS_SECRET_KEY
    SNAPPASS_SECRET_KEY="$(openssl rand -hex 32)"
  else
    export SNAPPASS_SECRET_KEY
    SNAPPASS_SECRET_KEY="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  fi
  success "SNAPPASS_SECRET_KEY generated."
fi

# ---------------------------------------------------------------------------
# Step 2: Ensure the resource group exists
# ---------------------------------------------------------------------------
log "Ensuring resource group '${RESOURCE_GROUP}' exists in '${LOCATION}'..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output none
success "Resource group ready."

# ---------------------------------------------------------------------------
# Step 3: Register required resource providers
# ---------------------------------------------------------------------------
log "Registering required Azure resource providers..."
for PROVIDER in \
  Microsoft.App \
  Microsoft.ContainerRegistry \
  Microsoft.Cache \
  Microsoft.ManagedIdentity \
  Microsoft.OperationalInsights; do
  az provider register --namespace "${PROVIDER}" --wait --output none
  log "  ${PROVIDER} registered."
done
success "Resource providers registered."

# ---------------------------------------------------------------------------
# Step 4: Install / upgrade Bicep
# ---------------------------------------------------------------------------
log "Ensuring Bicep CLI is up to date..."
az bicep install 2>/dev/null || az bicep upgrade 2>/dev/null || true
success "Bicep ready."

# ---------------------------------------------------------------------------
# Step 5: Deploy Bicep template
# ---------------------------------------------------------------------------
DEPLOYMENT_NAME="snappass-$(date +%Y%m%d%H%M%S)"
log "Starting Bicep deployment '${DEPLOYMENT_NAME}'..."
log "This typically takes 5-15 minutes (Redis provisioning is the longest step)."

DEPLOYMENT_OUTPUT=$(az deployment group create \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${INFRA_DIR}/main.bicep" \
  --parameters "${INFRA_DIR}/main.bicepparam" \
  --parameters baseName="${BASE_NAME}" \
  --output json)

success "Bicep deployment complete."

# Parse outputs
ACR_NAME=$(echo "${DEPLOYMENT_OUTPUT}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['acrName']['value'])")
ACR_LOGIN_SERVER=$(echo "${DEPLOYMENT_OUTPUT}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['acrLoginServer']['value'])")
APP_URL=$(echo "${DEPLOYMENT_OUTPUT}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['snappassUrl']['value'])")

log "ACR name:         ${ACR_NAME}"
log "ACR login server: ${ACR_LOGIN_SERVER}"
log "App URL:          ${APP_URL}"

# ---------------------------------------------------------------------------
# Step 6: Import SnapPass image from Docker Hub into ACR
# ---------------------------------------------------------------------------
log "Importing ${DOCKER_IMAGE} from Docker Hub into ACR '${ACR_NAME}'..."

az acr import \
  --name "${ACR_NAME}" \
  --source "docker.io/${DOCKER_IMAGE}" \
  --image "snappass:latest" \
  --force \
  --resource-group "${RESOURCE_GROUP}"

success "Image imported: ${ACR_LOGIN_SERVER}/snappass:latest"

# ---------------------------------------------------------------------------
# Step 7: Update Container App to use the ACR image
# ---------------------------------------------------------------------------
CONTAINER_APP_NAME="${BASE_NAME}-app"
log "Updating Container App '${CONTAINER_APP_NAME}' to use ACR image..."

az containerapp update \
  --name "${CONTAINER_APP_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --image "${ACR_LOGIN_SERVER}/snappass:latest" \
  --output none

success "Container App updated to ${ACR_LOGIN_SERVER}/snappass:latest"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  SnapPass deployed successfully!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  URL:       ${CYAN}${APP_URL}${NC}"
echo -e "  Group:     ${RESOURCE_GROUP}"
echo -e "  Image:     ${ACR_LOGIN_SERVER}/snappass:latest"
echo ""
echo -e "  To stream logs:"
echo -e "  ${CYAN}az containerapp logs show -n ${CONTAINER_APP_NAME} -g ${RESOURCE_GROUP} --follow${NC}"
echo ""
