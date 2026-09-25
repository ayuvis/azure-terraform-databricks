# azure-terraform-databricks
azure-terraform-databricks
# Azure Databricks Infrastructure with Terraform

Terraform project for provisioning a foundational **Azure Databricks platform** integrated with **Azure Data Lake Storage Gen2 (ADLS Gen2)** and **Unity Catalog**.

The project creates the Azure infrastructure and Databricks governance components required for a DevOps-oriented Databricks environment.

---

## Architecture

```text
                         Azure Subscription
                                |
                         +------+------+
                         | Resource   |
                         |   Group    |
                         +------+------+
                                |
             +------------------+------------------+
             |                                     |
             v                                     v
      Azure Databricks                         ADLS Gen2
         Workspace                             Storage Account
             |                                     |
             |                              +------+------+
             |                              |             |
             |                              v             v
             |                         unitycatalog     data
             |                              containers
             |
             v
       Unity Catalog
             |
      +------+-------+
      |              |
      v              v
   Catalog        Storage
  production     Credential
      |
      v
    Schema
    sales
      |
      v
External Location
      |
      v
   ADLS Gen2
```

### Main components

| Component                   | Purpose                                           |
| --------------------------- | ------------------------------------------------- |
| Azure Resource Group        | Logical container for Azure resources             |
| Azure Databricks Workspace  | Databricks compute and workspace platform         |
| ADLS Gen2                   | Cloud data storage                                |
| Databricks Access Connector | Azure managed identity used by Databricks         |
| Azure RBAC                  | Grants ADLS access to the managed identity        |
| Unity Catalog Metastore     | Central data governance layer                     |
| Unity Catalog               | Catalog/schema/table organization and permissions |
| Storage Credential          | Databricks identity for cloud storage             |
| External Location           | Governed reference to ADLS storage                |
| Terraform                   | Infrastructure as Code                            |

---

# Project Structure

```text
azure-databricks/
|
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── README.md
```

### File descriptions

#### `main.tf`

Contains the main infrastructure definitions:

* Azure Resource Group
* ADLS Gen2 Storage Account
* ADLS containers
* Azure Databricks Access Connector
* Azure RBAC assignment
* Azure Databricks Workspace
* Databricks providers
* Unity Catalog metastore
* Metastore data access
* Metastore assignment
* Unity Catalog catalog
* Unity Catalog schema
* Storage credential
* External location
* External location permissions

#### `variables.tf`

Defines configurable Terraform variables such as:

* Project name
* Environment
* Azure region
* Databricks account ID
* Metastore owner

#### `outputs.tf`

Returns useful values after deployment:

* Resource group name
* Storage account
* Databricks workspace
* Workspace URL
* Access Connector ID
* Metastore ID
* Catalog
* External location

#### `terraform.tfvars`

Contains environment-specific values.

Do **not** commit sensitive credentials or secrets into this file.

---

# Prerequisites

Before deploying this project, install the following tools.

## 1. Azure CLI

Install Azure CLI:

https://learn.microsoft.com/cli/azure/install-azure-cli

Verify:

```bash
az version
```

Login:

```bash
az login
```

Verify the currently selected subscription:

```bash
az account show
```

Change subscription:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

---

## 2. Terraform

Install Terraform:

https://developer.hashicorp.com/terraform/install

Verify:

```bash
terraform version
```

The project requires Terraform:

```text
>= 1.7.0
```

---

## 3. Azure permissions

The Azure identity running Terraform must have sufficient permissions to create the Azure resources used by this project.

At minimum, ensure the identity can create/manage:

* Resource Groups
* Storage Accounts
* Storage Containers
* Role Assignments
* Databricks Workspaces
* Databricks Access Connectors

For a lab subscription, Contributor-level access is commonly used.

For production, use a dedicated service principal or workload identity with only the required permissions.

---

# Azure Databricks Account ID

This project uses two Databricks provider configurations:

```text
1. Account-level provider
2. Workspace-level provider
```

The account-level provider is used for resources such as:

* Unity Catalog metastore
* Metastore assignment

The workspace-level provider is used for resources such as:

* Catalog
* Schema
* Storage credential
* External location
* Grants

The account-level provider requires the Databricks account ID.

Example:

```hcl
databricks_account_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

The Databricks account ID is **not** the Azure subscription ID.

---

# Configuration

Update `terraform.tfvars`:

```hcl
project_name = "mydatabricks"

environment = "dev"

location = "eastus"

databricks_account_id = "YOUR-DATABRICKS-ACCOUNT-ID"

metastore_owner = "your-email@company.com"
```

## Variables

### `project_name`

Used as the base name for generated Azure resources.

Example:

```hcl
project_name = "dataplatform"
```

### `environment`

Environment name.

Example:

```hcl
environment = "dev"
```

Typical values:

```text
dev
test
stage
prod
```

### `location`

Azure region where the resources will be deployed.

Example:

```hcl
location = "eastus"
```

The Databricks workspace and ADLS resources should be deployed in a suitable compatible region.

### `databricks_account_id`

Azure Databricks account ID.

Example:

```hcl
databricks_account_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### `metastore_owner`

Databricks user or group that owns the Unity Catalog metastore.

Example:

```hcl
metastore_owner = "admin@company.com"
```

For production, using a group rather than an individual account is generally preferable.

---

# Authentication

The local configuration uses Azure CLI authentication.

Login:

```bash
az login
```

Select subscription:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

The Databricks providers are configured to authenticate through Azure CLI.

Example:

```hcl
provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id

  auth_type = "azure-cli"
}
```

Workspace provider:

```hcl
provider "databricks" {
  alias = "workspace"

  host = azurerm_databricks_workspace.this.workspace_url

  auth_type = "azure-cli"

  azure_workspace_resource_id = azurerm_databricks_workspace.this.id
}
```

---

# Deployment

## Step 1 — Clone the repository

```bash
git clone <REPOSITORY_URL>
cd azure-databricks
```

---

## Step 2 — Authenticate with Azure

```bash
az login
```

Verify:

```bash
az account show
```

---

## Step 3 — Configure variables

Edit:

```text
terraform.tfvars
```

Example:

```hcl
project_name = "dataplatform"

environment = "dev"

location = "eastus"

databricks_account_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

metastore_owner = "admin@company.com"
```

---

## Step 4 — Initialize Terraform

```bash
terraform init
```

This downloads the required providers.

Expected providers include:

```text
hashicorp/azurerm
databricks/databricks
hashicorp/random
```

---

## Step 5 — Format the code

```bash
terraform fmt -recursive
```

---

## Step 6 — Validate the configuration

```bash
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

---

## Step 7 — Review the execution plan

```bash
terraform plan
```

Review the resources that Terraform intends to create.

Do not proceed if the plan contains unexpected resource destruction or changes.

---

## Step 8 — Deploy

```bash
terraform apply
```

Terraform will ask for confirmation.

Enter:

```text
yes
```

---

# Deployment Flow

Terraform creates the infrastructure in approximately this order:

```text
Resource Group
      |
      +---- ADLS Gen2
      |       |
      |       +---- unitycatalog container
      |       +---- data container
      |
      +---- Databricks Access Connector
      |          |
      |          +---- Managed Identity
      |
      +---- Azure RBAC
      |          |
      |          +---- Storage Blob Data Contributor
      |
      +---- Databricks Workspace
                 |
                 +---- Unity Catalog Metastore
                 |
                 +---- Metastore Data Access
                 |
                 +---- Metastore Assignment
                 |
                 +---- Catalog
                 |
                 +---- Schema
                 |
                 +---- Storage Credential
                 |
                 +---- External Location
                 |
                 +---- Grants
```

---

# Verify the Deployment

After a successful deployment:

```bash
terraform output
```

Get the Databricks workspace URL:

```bash
terraform output databricks_workspace_url
```

Example:

```text
https://adb-1234567890123456.7.azuredatabricks.net/
```

Open the URL in a browser.

---

# Azure Resources

The project creates an Azure resource group similar to:

```text
dataplatform-a1b2c3-rg
```

Inside the deployment you should see:

```text
Azure Databricks Workspace
Azure Databricks Access Connector
Storage Account
Storage Containers
```

The workspace may also create a Databricks-managed resource group.

---

# ADLS Gen2

The storage account uses:

```hcl
is_hns_enabled = true
```

This enables hierarchical namespace and makes the account suitable for ADLS Gen2 workloads.

The project creates:

```text
unitycatalog/
data/
```

The resulting paths are similar to:

```text
abfss://unitycatalog@<storage-account>.dfs.core.windows.net/

abfss://data@<storage-account>.dfs.core.windows.net/
```

---

# Managed Identity

The Databricks Access Connector receives a system-assigned managed identity.

Conceptually:

```text
Databricks
     |
     v
Access Connector
     |
     v
Managed Identity
     |
     v
Azure RBAC
     |
     v
ADLS Gen2
```

The project grants:

```text
Storage Blob Data Contributor
```

to that managed identity on the storage account.

This avoids embedding storage account credentials in Databricks configuration.

---

# Unity Catalog

The Terraform configuration creates a Unity Catalog metastore.

Structure:

```text
Metastore
   |
   +---- production
           |
           +---- sales
```

The catalog is:

```text
production
```

The schema is:

```text
sales
```

Therefore the fully qualified object naming pattern becomes:

```text
production.sales.<table_name>
```

Example:

```sql
SELECT *
FROM production.sales.orders;
```

---

# Storage Credential

The storage credential uses the Azure Databricks Access Connector:

```text
Databricks
    |
    v
Storage Credential
    |
    v
Azure Managed Identity
    |
    v
ADLS Gen2
```

Terraform:

```hcl
resource "databricks_storage_credential" "adls" {
  ...
}
```

No storage account key is required for this integration.

---

# External Location

The project creates an external location pointing to:

```text
abfss://data@<storage-account>.dfs.core.windows.net/
```

Databricks accesses the location through the configured storage credential.

This provides a governed Unity Catalog interface to cloud storage.

---

# Using the Databricks Workspace

After deployment:

1. Open the Databricks workspace URL.
2. Authenticate using Microsoft Entra ID.
3. Open **Catalog**.
4. Locate:

```text
production
└── sales
```

The schema can then be used by Databricks workloads.

---

# Example SQL

Inside a Databricks SQL editor or notebook:

```sql
SHOW CATALOGS;
```

Check schemas:

```sql
SHOW SCHEMAS IN production;
```

The expected schema includes:

```text
sales
```

Create a table:

```sql
CREATE TABLE production.sales.customers (
    customer_id BIGINT,
    customer_name STRING,
    email STRING,
    created_at TIMESTAMP
);
```

Query it:

```sql
SELECT *
FROM production.sales.customers;
```

---

# Terraform State

For a local experiment, Terraform creates:

```text
terraform.tfstate
```

Do **not** commit this file to Git.

Add the following to `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
terraform.tfvars
*.tfplan
```

For production, use a remote Azure Storage backend.

Recommended architecture:

```text
GitLab CI
    |
    v
Terraform
    |
    v
Azure Storage Backend
    |
    v
terraform.tfstate
```

This provides shared state and locking for a team.

---

# Recommended Production Backend

A typical production backend uses an Azure Storage Account.

Example:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatexxxxxxxx"
    container_name       = "tfstate"
    key                  = "databricks/dev.tfstate"
  }
}
```

Do not hard-code production credentials into the Terraform configuration.

Use Azure identity-based authentication for CI/CD where possible.

---

# Environment Structure

For multiple environments, use separate state files.

Example:

```text
Azure Databricks
|
+-- DEV
|    |
|    +-- dev.tfstate
|
+-- TEST
|    |
|    +-- test.tfstate
|
+-- PROD
     |
     +-- prod.tfstate
```

A repository can be structured as:

```text
azure-databricks/
|
├── modules/
│   ├── networking/
│   ├── storage/
│   ├── databricks/
│   ├── unity-catalog/
│   └── jobs/
|
└── environments/
    ├── dev/
    ├── test/
    └── prod/
```

This is preferable to maintaining one huge configuration for every environment.

---

# CI/CD

The intended next step is to run the Terraform workflow through GitLab CI/CD.

Recommended pipeline:

```text
Git Push
   |
   v
GitLab
   |
   +---- terraform fmt
   |
   +---- terraform validate
   |
   +---- terraform plan
   |
   v
Manual Approval
   |
   v
Terraform Apply
   |
   v
Azure Databricks
```

Example pipeline stages:

```yaml
stages:
  - validate
  - plan
  - deploy_dev
  - deploy_test
  - deploy_prod
```

Production should normally require an explicit approval before `terraform apply`.

---

# Security Recommendations

## Do not store credentials in Git

Never commit:

```text
Passwords
Client secrets
Storage keys
Access tokens
Terraform state
Private keys
```

Use:

```text
Azure Managed Identity
Microsoft Entra ID
Azure Key Vault
OIDC / Workload Identity
```

where appropriate.

---

# Recommended Production Improvements

This repository is intended as a foundation.

For a production implementation, consider adding:

### Networking

```text
VNet
Private Endpoints
Private DNS Zones
Network Security Groups
VNet injection
Private Link
```

### Security

```text
Azure Key Vault
Managed identities
OIDC
Conditional access
Databricks access controls
Unity Catalog grants
```

### Governance

```text
Cluster policies
Unity Catalog permissions
Audit logging
Azure Policy
Resource locks
Tagging standards
```

### Operations

```text
Azure Monitor
Diagnostic settings
Databricks audit logs
Cost Management
Alerts
Job monitoring
```

---

# Important Unity Catalog Consideration

A Databricks account can have an existing Unity Catalog metastore for a region.

Before running this project in an existing enterprise Databricks account, check whether a metastore already exists.

The Terraform resource:

```hcl
resource "databricks_metastore" "this"
```

should generally **not** be used to create a second metastore in a region where the organization's existing metastore is intended to be shared.

In an existing enterprise environment, a better pattern is often:

```text
Existing Databricks Account
        |
        v
Existing Unity Catalog Metastore
        |
        +---- DEV Workspace
        |
        +---- TEST Workspace
        |
        +---- PROD Workspace
```

Terraform can then manage:

```text
Workspace
Metastore Assignment
Catalogs
Schemas
Storage Credentials
External Locations
Permissions
Jobs
```

without attempting to recreate the organization's existing metastore.

---

# Troubleshooting

## `terraform init` fails

Run:

```bash
terraform init -upgrade
```

Then verify:

```bash
terraform version
```

---

## Azure authentication failure

Run:

```bash
az login
```

Check:

```bash
az account show
```

If multiple subscriptions are available:

```bash
az account list -o table
```

Select the correct one:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

---

## Databricks authentication failure

Verify:

```hcl
databricks_account_id = "..."
```

Make sure the account ID is the **Databricks account ID**, not the Azure subscription ID.

Also verify that the identity has appropriate Databricks account-level privileges.

---

## Unity Catalog metastore creation fails

Check whether a metastore already exists in the selected Databricks region.

If one already exists, use the existing metastore instead of creating another one.

---

## Storage access failure

Verify that the Access Connector managed identity has:

```text
Storage Blob Data Contributor
```

on the correct storage account.

The Terraform dependency is intentionally defined so that the role assignment exists before Unity Catalog storage access is configured.

---

## External location authorization failure

Check all of the following:

```text
Storage Account
        |
        +-- ADLS Gen2 / HNS enabled
        |
        +-- Access Connector
        |
        +-- Managed Identity
        |
        +-- Azure RBAC
        |
        +-- Databricks Storage Credential
        |
        +-- External Location
```

A missing permission at any level can result in an authorization error.

---

# Destroying the Environment

To remove the infrastructure:

```bash
terraform destroy
```

Review the plan carefully before confirming.

Then enter:

```text
yes
```

## Warning

This can permanently delete:

* Databricks workspace resources
* Storage containers
* ADLS data
* Unity Catalog objects

Do not run:

```bash
terraform destroy
```

against production without verifying exactly which resources are managed by the Terraform state.

---

# Useful Commands

Initialize:

```bash
terraform init
```

Format:

```bash
terraform fmt -recursive
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

Show outputs:

```bash
terraform output
```

Show state:

```bash
terraform show
```

List resources:

```bash
terraform state list
```

Destroy:

```bash
terraform destroy
```

---

# Recommended Git Workflow

```text
feature branch
     |
     v
Pull Request
     |
     v
terraform fmt
     |
     v
terraform validate
     |
     v
terraform plan
     |
     v
Code Review
     |
     v
Merge
     |
     v
Deploy DEV
     |
     v
Deploy TEST
     |
     v
Approval
     |
     v
Deploy PROD
```

Never allow developers to make uncontrolled infrastructure changes directly in production.

Terraform should remain the source of truth for the resources it manages.

---

# Future Enhancements

This project can be extended into a complete Azure Databricks platform with:

```text
Azure Databricks
|
+-- VNet Injection
|
+-- Private Link
|
+-- Private DNS
|
+-- ADLS Gen2
|
+-- Unity Catalog
|
+-- Cluster Policies
|
+-- SQL Warehouses
|
+-- Databricks Workflows
|
+-- Databricks Asset Bundles
|
+-- Azure Key Vault
|
+-- Managed Identities
|
+-- GitLab CI/CD
|
+-- OIDC Authentication
|
+-- Monitoring
|
+-- Audit Logging
|
+-- DEV / TEST / PROD
```

---

# Example Target Architecture

The complete production-oriented platform can eventually look like:

```text
                         GitLab
                            |
                            v
                      GitLab CI/CD
                            |
               +------------+-------------+
               |                          |
               v                          v
           Terraform               Databricks
               |                    Asset Bundles
               |                          |
       +-------+--------+                 |
       |                |                 |
       v                v                 v
     Azure          Databricks       Databricks Jobs
   Networking        Workspace             |
       |                 |                  |
       |                 v                  |
       |            Unity Catalog           |
       |                 |                  |
       +-----------------+------------------+
                         |
                         v
                     ADLS Gen2
                         |
              +----------+----------+
              |          |          |
              v          v          v
            Bronze     Silver      Gold
```

---

# Design Principles

This project follows these principles:

1. **Infrastructure as Code**
   Azure and Databricks infrastructure should be reproducible through Terraform.

2. **Identity-based access**
   Prefer managed identities and Microsoft Entra ID over static credentials.

3. **Centralized governance**
   Use Unity Catalog for data organization and access control.

4. **Separation of environments**
   DEV, TEST and PROD should have independent lifecycle and state management.

5. **CI/CD instead of manual changes**
   Infrastructure changes should go through version control and code review.

6. **Least privilege**
   Grant only the permissions required by each identity or group.

7. **Remote state for teams**
   Production Terraform state should be stored remotely and protected.

---

# Summary

This Terraform project provides a foundational Azure Databricks platform consisting of:

```text
Azure Resource Group
        +
ADLS Gen2
        +
Databricks Access Connector
        +
Managed Identity
        +
Azure RBAC
        +
Azure Databricks Premium Workspace
        +
Unity Catalog Metastore
        +
Catalog
        +
Schema
        +
Storage Credential
        +
External Location
```

It is suitable as a starting point for a DevOps implementation and can be extended with private networking, enterprise security, environment separation, GitLab CI/CD and Databricks Asset Bundles.

---

# License

Add your organization's license information here.

For example:

```text
Internal / Proprietary
```

---

# Author / Ownership

```text
Infrastructure managed using Terraform.
Cloud: Microsoft Azure
Platform: Azure Databricks
Storage: Azure Data Lake Storage Gen2
Governance: Unity Catalog
CI/CD: GitLab
```
