# Azure Infrastructure Deployment with Terraform

This repository contains Terraform configuration to deploy basic Azure networking infrastructure, automated through GitHub Actions.

## 📋 What This Repository Does

This Terraform configuration creates the following Azure resources:

- **Resource Group** (`demo1`) in East US region
- **Virtual Network** (`vnetdemo1`) with address space `10.0.0.0/16`
- **Subnet** (`subnetdemo1`) with address prefix `10.0.1.0/24`

The infrastructure can be automatically deployed via GitHub Actions or manually using Terraform CLI.

## 🛠️ Requirements

### Tools & Software
- **Terraform** >= 1.5.0 (workflow uses v1.9.0)
- **Azure CLI** (for local development and authentication)
- **Git** (for version control)

### Azure Requirements
- **Azure Subscription** (active subscription with permissions to create resources)
- **Azure Service Principal** with Contributor role (for GitHub Actions authentication)

### GitHub Requirements
- **GitHub Account** with access to GitHub Actions
- **Repository Secrets** configured (see setup section below)

## 🚀 Setup Instructions

### 1. Azure Service Principal Setup

Create a service principal for GitHub Actions authentication:

```bash
# Login to Azure
az login

# Create service principal (replace with your subscription ID)
az ad sp create-for-rbac \
  --name "github-actions-terraform" \
  --role contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
  --sdk-auth
```

This command will output JSON credentials that you'll need for the next step.

### 2. Configure GitHub Secrets

Add the following secret to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Create a secret named `AZURE_CREDENTIALS`
5. Paste the entire JSON output from the service principal creation

The JSON should look like this:
```json
{
  "clientId": "xxx",
  "clientSecret": "xxx",
  "subscriptionId": "xxx",
  "tenantId": "xxx"
}
```

### 3. Clone the Repository

```bash
git clone <your-repo-url>
cd <your-repo-name>
```

## 📖 Usage

### Option 1: Automated Deployment via GitHub Actions

#### Deploy Infrastructure

The workflow runs automatically on:
- **Push to main branch** - Automatically deploys infrastructure
- **Manual trigger** - Deploy or destroy via GitHub UI

**To manually deploy:**
1. Go to **Actions** tab in GitHub
2. Select **Deploy to Azure with Terraform** workflow
3. Click **Run workflow**
4. Select branch: `main`
5. Choose action: `deploy`
6. Click **Run workflow**

#### Destroy Infrastructure

**To manually destroy:**
1. Go to **Actions** tab in GitHub
2. Select **Deploy to Azure with Terraform** workflow
3. Click **Run workflow**
4. Select branch: `main`
5. Choose action: `destroy`
6. Click **Run workflow**

### Option 2: Local Deployment with Terraform CLI

#### Prerequisites for Local Use

Authenticate with Azure:
```bash
az login
```

#### Initialize Terraform

```bash
terraform init
```

#### Plan Changes

```bash
terraform plan
```

#### Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

#### Destroy Infrastructure

```bash
terraform destroy
```

Type `yes` when prompted to confirm.

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml       # GitHub Actions workflow
├── .gitignore              # Git ignore rules
├── main.tf                 # Terraform configuration
└── README.md               # This file
```

## 🔒 State Management

The GitHub Actions workflow uses **GitHub Artifacts** to store Terraform state between runs:

- State is uploaded after successful apply operations
- State is downloaded at the beginning of each workflow run
- State files are retained for 90 days
- ⚠️ **Note:** This is suitable for demos/testing. For production, use Azure Storage Backend or Terraform Cloud.

## ⚙️ Configuration

### Modify Resources

To customize the infrastructure, edit `main.tf`:

- Change **location**: Update the `location` field in the resource group
- Change **address space**: Modify VNET `address_space` or subnet `address_prefixes`
- Change **resource names**: Update the `name` fields for each resource

### Modify Terraform Version

To use a different Terraform version, edit `.github/workflows/deploy.yml`:

```yaml
terraform_version: 1.9.0   # Change this version
```

## 🔍 Monitoring Deployments

1. Go to the **Actions** tab in your GitHub repository
2. Click on the latest workflow run
3. Expand the steps to view detailed logs
4. Check for any errors or warnings

## 🧹 Cleanup

To completely remove all resources:

1. Run the destroy workflow (Option 1 above), OR
2. Run `terraform destroy` locally (Option 2 above)
3. Optionally delete the service principal:
   ```bash
   az ad sp delete --id <client-id>
   ```

## ⚠️ Important Notes

- The workflow runs automatically on every push to `main` branch
- State files are stored as GitHub Artifacts (not recommended for production)
- Ensure your Azure subscription has sufficient quota for the resources
- Review the plan output before applying changes