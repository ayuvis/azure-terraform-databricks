variable "project_name" {
  description = "Project name used for Azure resource naming."
  type        = string
  default     = "adbplatform"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region. Keep the Databricks workspace and ADLS in the same region."
  type        = string
  default     = "eastus"
}

variable "databricks_account_id" {
  description = "Azure Databricks account ID."
  type        = string
}

variable "metastore_owner" {
  description = "Databricks user or group that will own the Unity Catalog metastore."
  type        = string
}
