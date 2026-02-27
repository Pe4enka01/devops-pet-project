#!/bin/bash
# stop.sh — Destroy expensive Azure resources to stop billing.
# Run this when you're done studying: bash stop.sh
#
# What gets DESTROYED (stops costing money):
#   - ACI Container Group (FastAPI + Prometheus + Grafana)
#   - PostgreSQL Flexible Server + Database + Firewall rule
#
# What STAYS (free or near-free, contains your work):
#   - Azure Container Registry (your Docker images)
#   - Storage Account (Terraform state)
#   - VNet / Subnets (free)
#   - Resource Group itself (free)

set -e  # Stop script if any command fails

cd "$(dirname "$0")/terraform"

echo "🛑 Stopping expensive Azure resources..."
echo "   (Your code, images, and Terraform state are safe)"
echo ""

# Initialize Terraform (syncs with the remote state in Azure)
echo "🔄 Initializing Terraform..."
terraform init -upgrade
terraform init -reconfigure

# Order matters: destroy resources that depend on others first
terraform destroy \
  -target=azurerm_container_group.fastapi_cg \
  -target=azurerm_postgresql_flexible_server_database.pet_db \
  -target=azurerm_postgresql_flexible_server_firewall_rule.allow_access \
  -target=azurerm_postgresql_flexible_server.db_server \
  -auto-approve

echo ""
echo "✅ Done! Azure is no longer billing you for compute or database."
echo "   Run 'bash start.sh' when you're ready to study again."
