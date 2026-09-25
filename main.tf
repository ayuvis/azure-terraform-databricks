terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.4.0"
    }

    databricks = {
      source  = "databricks/databricks"
      version = "1.130.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

provider "azurerm" {
  features {}
}

# ------------------------------------------------------------
# Azure account information
# ------------------------------------------------------------

data "azurerm_client_config" "current" {}

# ------------------------------------------------------------
# Random suffix
# ------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  prefix = "${var.project_name}-${random_string.suffix.result}"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

# ------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = "${local.prefix}-rg"
  location = var.location

  tags = local.tags
}

# ------------------------------------------------------------
# ADLS Gen2 Storage Account
# ------------------------------------------------------------

resource "azurerm_storage_account" "data" {
  name = substr(
    lower(replace("${local.prefix}data", "-", "")),
    0,
    24
  )

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  is_hns_enabled = true

  min_tls_version           = "TLS1_2"
  shared_access_key_enabled = true

  tags = local.tags
}

# ------------------------------------------------------------
# Container for Unity Catalog managed storage
# ------------------------------------------------------------

resource "azurerm_storage_container" "unity_catalog" {
  name                  = "unitycatalog"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

# ------------------------------------------------------------
# Container for application/data files
# ------------------------------------------------------------

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

# ------------------------------------------------------------
# Azure Databricks Access Connector
# ------------------------------------------------------------

resource "azurerm_databricks_access_connector" "this" {
  name                = "${local.prefix}-access-connector"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# ------------------------------------------------------------
# Allow Access Connector managed identity to access ADLS
# ------------------------------------------------------------

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id

  principal_type = "ServicePrincipal"
}

# ------------------------------------------------------------
# Azure Databricks Workspace
# ------------------------------------------------------------

resource "azurerm_databricks_workspace" "this" {
  name                = "${local.prefix}-workspace"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  sku = "premium"

  managed_resource_group_name = "${local.prefix}-managed-rg"

  tags = local.tags

  depends_on = [
    azurerm_resource_group.this
  ]
}

# ------------------------------------------------------------
# ACCOUNT-LEVEL DATABRICKS PROVIDER
# ------------------------------------------------------------

provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id

  auth_type = "azure-cli"
}

# ------------------------------------------------------------
# WORKSPACE-LEVEL DATABRICKS PROVIDER
# ------------------------------------------------------------

provider "databricks" {
  alias = "workspace"

  host = azurerm_databricks_workspace.this.workspace_url

  auth_type = "azure-cli"

  azure_workspace_resource_id = azurerm_databricks_workspace.this.id
}

# ------------------------------------------------------------
# UNITY CATALOG METASTORE
# ------------------------------------------------------------

resource "databricks_metastore" "this" {
  provider = databricks.accounts

  name = "${local.prefix}-metastore"

  storage_root = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.unity_catalog.name,
    azurerm_storage_account.data.name
  )

  region = var.location

  owner = var.metastore_owner

  force_destroy = true

  depends_on = [
    azurerm_role_assignment.storage_blob_data_contributor
  ]
}

# ------------------------------------------------------------
# Give Unity Catalog access to the metastore storage
# ------------------------------------------------------------

resource "databricks_metastore_data_access" "this" {
  provider = databricks.accounts

  metastore_id = databricks_metastore.this.id
  name         = "${local.prefix}-metastore-access"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.this.id
  }

  is_default = true

  depends_on = [
    databricks_metastore.this,
    azurerm_role_assignment.storage_blob_data_contributor
  ]
}

# ------------------------------------------------------------
# Attach metastore to workspace
# ------------------------------------------------------------

resource "databricks_metastore_assignment" "this" {
  provider = databricks.accounts

  metastore_id = databricks_metastore.this.id
  workspace_id = azurerm_databricks_workspace.this.workspace_id

  depends_on = [
    databricks_metastore_data_access.this
  ]
}

# ------------------------------------------------------------
# Unity Catalog
# ------------------------------------------------------------

resource "databricks_catalog" "production" {
  provider = databricks.workspace

  name    = "production"
  comment = "Production data catalog managed by Terraform"

  depends_on = [
    databricks_metastore_assignment.this
  ]
}

# ------------------------------------------------------------
# Schema
# ------------------------------------------------------------

resource "databricks_schema" "sales" {
  provider = databricks.workspace

  catalog_name = databricks_catalog.production.name
  name         = "sales"

  comment = "Sales data schema"
}

# ------------------------------------------------------------
# Storage Credential
# ------------------------------------------------------------

resource "databricks_storage_credential" "adls" {
  provider = databricks.workspace

  name = "${local.prefix}-adls-credential"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.this.id
  }

  comment = "Managed identity credential for ADLS Gen2"

  depends_on = [
    databricks_metastore_assignment.this,
    azurerm_role_assignment.storage_blob_data_contributor
  ]
}

# ------------------------------------------------------------
# External Location
# ------------------------------------------------------------

resource "databricks_external_location" "data" {
  provider = databricks.workspace

  name = "${local.prefix}-data-location"

  url = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.data.name,
    azurerm_storage_account.data.name
  )

  credential_name = databricks_storage_credential.adls.name

  comment = "ADLS Gen2 external location managed by Terraform"

  depends_on = [
    databricks_storage_credential.adls
  ]
}

# ------------------------------------------------------------
# Grant external location usage to metastore admins
# ------------------------------------------------------------

resource "databricks_grants" "data_location" {
  provider = databricks.workspace

  external_location = databricks_external_location.data.id

  grant {
    principal  = var.metastore_owner
    privileges = ["CREATE_EXTERNAL_TABLE", "CREATE_MANAGED_STORAGE"]
  }
}
