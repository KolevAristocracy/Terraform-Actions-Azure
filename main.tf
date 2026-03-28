terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "edf11efa-4f3d-4a77-b3e3-4eaadc1c0166"
}

# Generate a random integer to create a globally unique name
resource "random_integer" "random" {
  min = 10000
  max = 99999
}


resource "azurerm_resource_group" "azureregistry" {
  name     = "${var.resource_group_name}-${random_integer.random.result}"
  location = var.location
}

resource "azurerm_service_plan" "azureapp_service" {
  name                = "${var.app_service_plan_name}-${random_integer.random.result}"
  location            = azurerm_resource_group.azureregistry.location
  resource_group_name = azurerm_resource_group.azureregistry.name
  os_type             = "Linux"
  sku_name            = "F1"
}

# Create the web app, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "azurewebapp" {
  name                = "${var.app_service_name}-${random_integer.random.result}"
  location            = azurerm_resource_group.azureregistry.location
  resource_group_name = azurerm_resource_group.azureregistry.name
  service_plan_id     = azurerm_service_plan.azureapp_service.id
  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.database.name};User ID=${azurerm_mssql_server.sqlserver.administrator_login};Password=${azurerm_mssql_server.sqlserver.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}


resource "azurerm_mssql_server" "sqlserver" {
  name                         = "${var.sql_server_name}-${random_integer.random.result}"
  resource_group_name          = azurerm_resource_group.azureregistry.name
  location                     = azurerm_resource_group.azureregistry.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "database" {
  name                 = var.sql_database_name
  server_id            = azurerm_mssql_server.sqlserver.id
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  license_type         = "LicenseIncluded"
  max_size_gb          = 2
  sku_name             = "Basic"
  zone_redundant       = false
  storage_account_type = "Local"

  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_mssql_firewall_rule" "firewall_rule" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}


# Deploy code from a public GitHub repository
resource "azurerm_app_service_source_control" "azurewebappsourcecontrol" {
  app_id   = azurerm_linux_web_app.azurewebapp.id
  branch   = "main"
  repo_url = var.github_repo_url
}