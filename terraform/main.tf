resource "azurerm_resource_group" "pet_project_rg" {
  name     = "rg-devops-pet-project"
  location = "West Europe"

  tags = {
    environment = "dev"
    owner = "Andrew" 
    project = "first-pet-project"
  }
}

# 2. Виртуальная сеть (Бесплатно)
resource "azurerm_virtual_network" "pet_vnet" {
  name                = "vnet-pet-project"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.pet_project_rg.location
  resource_group_name = azurerm_resource_group.pet_project_rg.name
}

# 3. Публичная подсеть (для FastAPI контейнеров)
resource "azurerm_subnet" "public_subnet" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.pet_project_rg.name
  virtual_network_name = azurerm_virtual_network.pet_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Приватная подсеть (для будущей базы данных)
resource "azurerm_subnet" "private_subnet" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.pet_project_rg.name
  virtual_network_name = azurerm_virtual_network.pet_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Генератор случайных 4 символов для уникальности имени
resource "random_string" "acr_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Ресурс ACR
resource "azurerm_container_registry" "acr" {
  # Итоговое имя будет типа acrpetandrew1234
  name                = "acrpetandrew${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.pet_project_rg.name
  location            = azurerm_resource_group.pet_project_rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Важный Output: он выведет имя в консоль GitHub Actions, чтобы Docker знал куда пушить
output "acr_name" {
  value = azurerm_container_registry.acr.name
}

resource "azurerm_container_group" "fastapi_cg" {
  name                = "cg-fastapi-app"
  location            = azurerm_resource_group.pet_project_rg.location
  resource_group_name = azurerm_resource_group.pet_project_rg.name
  ip_address_type     = "Public"
  os_type             = "Linux"

  container {
    name   = "fastapi-container"
    image  = "${azurerm_container_registry.acr.login_server}/fastapi-app:latest"
    cpu    = "0.5" # Берем минимум, чтобы сэкономить
    memory = "1.0"

    ports {
      port     = 8000
      protocol = "TCP"
    }
  }

  # Передаем данные для авторизации в ACR
  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}

output "app_url" {
  value = "http://${azurerm_container_group.fastapi_cg.ip_address}:8000"
}