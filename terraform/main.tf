resource "azurerm_resource_group" "pet_project_rg" {
  name     = "rg-devops-pet-project"
  location = "West Europe"

  tags = {
    environment = "dev"
    owner = "Andrew" 
    project = "first-pet-project"
  }
}