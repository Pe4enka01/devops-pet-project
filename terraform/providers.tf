terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # --- ДОБАВЛЯЕМ ЭТОТ БЛОК ---
  backend "azurerm" {
    resource_group_name  = "rg-devops-pet-2d5ad629" 
    storage_account_name = "petproject1" # Вставь имя, которое создал выше
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}