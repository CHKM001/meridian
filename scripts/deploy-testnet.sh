#!/usr/bin/env bash
set -euo pipefail

# Deploy a full, freshly-wired Meridian coordinator vault stack to Stellar
# testnet: vault, router, and a BlendAdapter, initialized and linked together.
# Use this to stand up a brand new environment. To push new adapter code to
# an ALREADY-LIVE vault without redeploying the vault itself, use
# scripts/redeploy-blend-adapter.sh instead.
#
# Usage: bash scripts/deploy-testnet.sh

NETWORK="testnet"

# DEPLOYER must be set in the environment and funded via friendbot. It becomes
# the admin of the deployed vault.
: "${DEPLOYER:?DEPLOYER env var required (Stellar secret key)}"

# Existing testnet assets/protocol contracts this deployment wires the vault
# to. Override via env var to point at different addresses.
USDC_ID="${USDC_ID:-CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU}"
BLEND_POOL_ID="${BLEND_POOL_ID:-CCEBVDYM32YNYCVNRXQKDFFPISJJCV557CDZEIRBEE4NCV4KHPQ44HGF}"

echo "Building contracts..."
cd "$(dirname "$0")/../packages/contracts"
stellar contract build

# `stellar contract build` targets wasm32v1-none, not wasm32-unknown-unknown.
WASM_DIR="target/wasm32v1-none/release"
WASM_VAULT="$WASM_DIR/meridian_vault.wasm"
WASM_ROUTER="$WASM_DIR/meridian_router.wasm"
WASM_BLEND_ADAPTER="$WASM_DIR/meridian_blend_adapter.wasm"

DEPLOYER_ADDRESS=$(stellar keys address "$DEPLOYER")

upload() {
  stellar contract upload --network "$NETWORK" --source "$DEPLOYER" --wasm "$1"
}
deploy() {
  stellar contract deploy --network "$NETWORK" --source "$DEPLOYER" --wasm-hash "$1"
}

echo "Uploading vault WASM..."
VAULT_HASH=$(upload "$WASM_VAULT")
echo "Uploading router WASM..."
ROUTER_HASH=$(upload "$WASM_ROUTER")
echo "Uploading blend-adapter WASM..."
BLEND_ADAPTER_HASH=$(upload "$WASM_BLEND_ADAPTER")

echo "Deploying vault..."
VAULT_ID=$(deploy "$VAULT_HASH")
echo "vault contract ID: $VAULT_ID"

echo "Deploying router..."
ROUTER_ID=$(deploy "$ROUTER_HASH")
echo "router contract ID: $ROUTER_ID"

echo "Deploying blend-adapter..."
BLEND_ADAPTER_ID=$(deploy "$BLEND_ADAPTER_HASH")
echo "blend-adapter contract ID: $BLEND_ADAPTER_ID"

echo "Deploying mUSDC share token (Stellar Asset Contract)..."
MUSDC_ID=$(stellar contract asset deploy \
  --network "$NETWORK" \
  --source "$DEPLOYER" \
  --asset "MUSDC:$DEPLOYER_ADDRESS")
echo "mUSDC contract ID: $MUSDC_ID"

echo "Initializing blend-adapter (pool=$BLEND_POOL_ID, usdc=$USDC_ID)..."
stellar contract invoke \
  --network "$NETWORK" --source "$DEPLOYER" --id "$BLEND_ADAPTER_ID" \
  -- initialize --vault "$VAULT_ID" --pool "$BLEND_POOL_ID" --usdc "$USDC_ID"

echo "Initializing vault (admin=$DEPLOYER_ADDRESS, usdc=$USDC_ID, musdc=$MUSDC_ID, adapter=$BLEND_ADAPTER_ID)..."
stellar contract invoke \
  --network "$NETWORK" --source "$DEPLOYER" --id "$VAULT_ID" \
  -- initialize \
  --admin "$DEPLOYER_ADDRESS" --usdc "$USDC_ID" --musdc "$MUSDC_ID" --adapter "$BLEND_ADAPTER_ID"

echo "Setting the vault as mUSDC's admin so it can mint/burn shares..."
stellar contract invoke \
  --network "$NETWORK" --source "$DEPLOYER" --id "$MUSDC_ID" \
  -- set_admin --new-admin "$VAULT_ID"

echo ""
echo "Done. Add these to your .env:"
echo "  VAULT_CONTRACT_ID=$VAULT_ID"
echo "  ROUTER_CONTRACT_ID=$ROUTER_ID"
echo "  BLEND_ADAPTER_CONTRACT_ID=$BLEND_ADAPTER_ID"
echo "  MUSDC_CONTRACT_ID=$MUSDC_ID"
