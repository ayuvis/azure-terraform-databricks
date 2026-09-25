output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  value = azurerm_storage_account.data.name
}

output "databricks_workspace_name" {
  value = azurerm_databricks_workspace.this.name
}

output "databricks_workspace_url" {
  value = "https://${azurerm_databricks_workspace.this.workspace_url}/"
}

output "access_connector_id" {
  value = azurerm_databricks_access_connector.this.id
}

output "metastore_id" {
  value = databricks_metastore.this.id
}

output "catalog_name" {
  value = databricks_catalog.production.name
}

output "external_location" {
  value = databricks_external_location.data.url
}
