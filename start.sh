#!/bin/bash
# start.sh — Recreate all Azure resources and start the app.
# Run this when you start studying: bash start.sh
#
# What gets CREATED:
#   - PostgreSQL Flexible Server + Database + Firewall rule
#   - ACI Container Group (FastAPI + Prometheus + Grafana)
#
# Terraform reads the saved state and only creates what's missing.
# Takes approximately 5-10 minutes (PostgreSQL takes the longest).

set -e  # Stop script if any command fails

cd "$(dirname "$0")/terraform"

echo "🚀 Starting Azure resources..."
echo ""

# Initialize Terraform (syncs with the remote state in Azure)
echo "🔄 Initializing Terraform..."
terraform init -upgrade
terraform init -reconfigure 

terraform apply -auto-approve

echo ""
echo "✅ Everything is running! Your URLs:"
# Print the output values from Terraform
terraform output
