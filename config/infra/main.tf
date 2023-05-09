terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

variable "CLIENT_NAME" {
  default = "adelmar"
}

variable "ENVIRONMENT" {
  default = "stg"
}


variable "ARM_SUBSCRIPTION_ID" {
  default = "default value"
}

variable "ARM_TENANT_ID" {
  default = "default value"
}

variable "ARM_CLIENT_ID" {
  default = "default value"
}

variable "ARM_CLIENT_SECRET" {
  default = "default value"
}

resource "null_resource" "test-setting-variables" {
  provisioner "local-exec" {
    command = "echo ${var.ARM_SUBSCRIPTION_ID} ${var.ARM_TENANT_ID} ${var.ARM_CLIENT_ID} ${var.ARM_CLIENT_ID}"
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.ARM_SUBSCRIPTION_ID
  tenant_id       = var.ARM_TENANT_ID
  client_id       = var.ARM_CLIENT_ID
  client_secret   = var.ARM_CLIENT_SECRET
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "client_4i" {
  name     = "rg-${var.CLIENT_NAME}-${var.ENVIRONMENT}"
  location = "Brazil South"
  tags = {
    environment = var.ENVIRONMENT
    client      = var.CLIENT_NAME
  }

}

resource "azurerm_storage_account" "storage_account" {
  name                     = "sa${var.CLIENT_NAME}${var.ENVIRONMENT}"
  resource_group_name      = azurerm_resource_group.client_4i.name
  location                 = azurerm_resource_group.client_4i.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.ENVIRONMENT
    client      = var.CLIENT_NAME
  }
}


resource "azurerm_storage_data_lake_gen2_filesystem" "storage_dl" {
  name               = "st-${var.CLIENT_NAME}-${var.ENVIRONMENT}"
  storage_account_id = azurerm_storage_account.storage_account.id

}

resource "azurerm_synapse_workspace" "workspace" {
  name                                 = "ws-${var.CLIENT_NAME}-${var.ENVIRONMENT}"
  resource_group_name                  = azurerm_resource_group.client_4i.name
  location                             = azurerm_resource_group.client_4i.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.storage_dl.id
  sql_administrator_login              = "admin4i"
  sql_administrator_login_password     = "P@ssw0rd"

  aad_admin {
    login     = "AzureAD Admin"
    object_id = data.azurerm_client_config.current.object_id
    tenant_id = var.ARM_TENANT_ID
  }

  tags = {
    environment = var.ENVIRONMENT
    client      = var.CLIENT_NAME
  }

}

resource "azurerm_synapse_spark_pool" "sparkpool" {
  name                 = "spk${var.CLIENT_NAME}${var.ENVIRONMENT}"
  synapse_workspace_id = azurerm_synapse_workspace.workspace.id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"
  cache_size           = 0

  auto_scale {
    max_node_count = 3
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = 8
  }

  library_requirement {
    content  = <<EOF
appnope==0.1.0
beautifulsoup4==4.6.3
EOF
    filename = "requirements.txt"
  }

  spark_config {
    content  = <<EOF
spark.shuffle.spill                true
EOF
    filename = "config.txt"
  }

  tags = {
    environment = var.ENVIRONMENT
    client      = var.CLIENT_NAME
  }
}

# resource "azurerm_synapse_sql_pool" "example" {
#   name                 = "-${var.CLIENT_NAME}-${var.ENVIRONMENT}"
#   synapse_workspace_id = azurerm_synapse_workspace.example.id
#   sku_name             = "DW100c"
#   create_mode          = "Default"
# }
