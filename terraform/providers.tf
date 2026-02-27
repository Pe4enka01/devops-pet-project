terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # --- ДОБАВЛЯЕМ ЭТОТ БЛОК ---
  backend "azurerm" {
    resource_group_name  = "rg-terraform-tfstate"      # Вечная группа
    storage_account_name = "tfstatepetproject2d5ad"    # Вечный сторедж
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