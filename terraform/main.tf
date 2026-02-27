# resource "random_id" "suffix" {
#   byte_length = 4
# }

# ЗАМЕНИ НА СТАТИКУ (используй тот ID, который сейчас в портале, например 2d5ad629)
locals {
  suffix = "2d5ad629"
}

# 1. ГРУППА РЕСУРСОВ
resource "azurerm_resource_group" "pet_project_rg" {
  name     = "rg-devops-pet-${local.suffix}"
  location = "North Europe"

  tags = {
    environment = "dev"
    owner       = "Andrew"
    project     = "first-pet-project"
  }
}

# 2. ХРАНИЛИЩЕ ДЛЯ ТЕRRАFORM STATE (Тот самый "дом" для стейта в Ирландии)
resource "azurerm_storage_account" "tfstate_storage" {
  name                     = "petproject${local.suffix}" # Добавил суффикс для уникальности
  resource_group_name      = azurerm_resource_group.pet_project_rg.name
  location                 = azurerm_resource_group.pet_project_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "tfstate_container" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate_storage.id
  container_access_type = "private"
}

# 3. СЕТЬ
resource "azurerm_virtual_network" "pet_vnet" {
  name                = "vnet-pet-project"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.pet_project_rg.location
  resource_group_name = azurerm_resource_group.pet_project_rg.name
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.pet_project_rg.name
  virtual_network_name = azurerm_virtual_network.pet_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private_subnet" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.pet_project_rg.name
  virtual_network_name = azurerm_virtual_network.pet_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 4. РЕЕСТР КОНТЕЙНЕРОВ (ACR)

resource "azurerm_container_registry" "acr" {
  name                = "acrpetandrew${local.suffix}"
  resource_group_name = azurerm_resource_group.pet_project_rg.name
  location            = azurerm_resource_group.pet_project_rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# 5. БАЗА ДАННЫХ POSTGRESQL
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "db_server" {
  name                   = "psql-pet-project-${local.suffix}"
  resource_group_name    = azurerm_resource_group.pet_project_rg.name
  location               = azurerm_resource_group.pet_project_rg.location
  version                = "14"
  administrator_login    = "psqladmin"
  administrator_password = random_password.db_password.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  backup_retention_days  = 7

  lifecycle {
    ignore_changes = [
      zone,
      high_availability
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "pet_db" {
  name      = "fastapi_db"
  server_id = azurerm_postgresql_flexible_server.db_server.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_access" {
  name             = "allow-all-azure"
  server_id        = azurerm_postgresql_flexible_server.db_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# 6. КОНТЕЙНЕР С ПРИЛОЖЕНИЕМ (ACI)
resource "azurerm_container_group" "fastapi_cg" {
  name                = "cg-fastapi-app"
  location            = azurerm_resource_group.pet_project_rg.location
  resource_group_name = azurerm_resource_group.pet_project_rg.name
  ip_address_type     = "Public"
  os_type             = "Linux"

  depends_on = [azurerm_postgresql_flexible_server_database.pet_db]

  # ── CRITICAL: Azure ACI requires ports declared in TWO places: ───────────────
  # 1. Inside each container{} — tells the container what to LISTEN on internally
  # 2. Here (exposed_port on the GROUP) — tells Azure to open these ports to the
  #    public internet. Without this block, all external traffic is silently refused
  #    even though the container is listening. This was the cause of "connection reset".
  exposed_port {
    port     = 8000
    protocol = "TCP"
  }

  exposed_port {
    port     = 9090
    protocol = "TCP"
  }

  exposed_port {
    port     = 3000
    protocol = "TCP"
  }

  # ─── FASTAPI APP ────────────────────────────────────────────────────────────
  container {
    name   = "fastapi-container"
    image  = "${azurerm_container_registry.acr.login_server}/fastapi-app:latest"
    cpu    = 0.5
    memory = 1.0

    ports {
      port     = 8000
      protocol = "TCP"
    }

    secure_environment_variables = {
      "DB_PASSWORD" = random_password.db_password.result
    }

    environment_variables = {
      "DB_USER" = "psqladmin"
      "DB_HOST" = azurerm_postgresql_flexible_server.db_server.fqdn
      "DB_NAME" = azurerm_postgresql_flexible_server_database.pet_db.name
    }
  }

  # ─── PROMETHEUS SIDECAR ─────────────────────────────────────────────────────
  # "Sidecar" = a helper container that runs alongside your main app
  # in the same container group (same network, same lifecycle)
  container {
    name   = "prometheus"
    image  = "${azurerm_container_registry.acr.login_server}/custom-prometheus:latest"
    cpu    = 0.25
    memory = 0.5

    ports {
      port     = 9090
      protocol = "TCP"
    }
  }

  # ─── GRAFANA SIDECAR ────────────────────────────────────────────────────────
  # Grafana is the visualization layer — it reads from Prometheus and shows dashboards
  container {
    name = "grafana"
    # Pinned to stable release — check https://github.com/grafana/grafana/releases
    image  = "grafana/grafana:10.4.2"
    cpu    = 0.25
    memory = 0.5

    ports {
      port     = 3000
      protocol = "TCP"
    }

    environment_variables = {
      "GF_PATHS_PROVISIONING"      = "/etc/grafana/provisioning"
      "GF_AUTH_ANONYMOUS_ENABLED"  = "true"
      "GF_AUTH_ANONYMOUS_ORG_ROLE" = "Viewer"
    }
  }

  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}


# 7. ВЫВОД ДАННЫХ (OUTPUTS)
# These are printed to the terminal after "terraform apply" completes
output "app_url" {
  value = "http://${azurerm_container_group.fastapi_cg.ip_address}:8000"
}

output "prometheus_url" {
  description = "Open /targets here to confirm FastAPI is being scraped"
  value       = "http://${azurerm_container_group.fastapi_cg.ip_address}:9090"
}

output "grafana_url" {
  description = "Grafana UI — login admin/admin, add Prometheus datasource at localhost:9090"
  value       = "http://${azurerm_container_group.fastapi_cg.ip_address}:3000"
}

output "db_host" {
  value = azurerm_postgresql_flexible_server.db_server.fqdn
}
