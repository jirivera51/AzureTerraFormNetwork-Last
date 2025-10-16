# Azure Infrastructure Deployment with Terraform

This repository contains Terraform configuration to deploy a complete Azure infrastructure with automated VM management, deployed through GitHub Actions.

## 📋 What This Repository Deploys

This Terraform configuration creates the following Azure resources:

### Networking
- **Resource Group** (`demo1`) in East US region
- **Virtual Network** (`vnetdemo1`) with address space `10.0.0.0/16`
- **Subnet** (`subnetdemo1`) with address prefix `10.0.1.0/24`
- **Network Security Group** with rules for:
  - HTTP (port 80)
  - HTTPS (port 443)
  - RDP (port 3389)

### Compute Resources
- **1 Standalone Windows VM** (`vm-demo1`)
  - Windows Server 2022 Datacenter
  - Standard_D2s_v3 size
  - Public IP address
  
- **2 Load-Balanced Web VMs** (`vm-web-1`, `vm-web-2`)
  - Windows Server 2022 Datacenter with IIS
  - Standard_D2s_v3 size
  - Serving "Hello World" web application
  - Configured in availability set for high availability

### Load Balancing
- **Azure Load Balancer** (`lb-web`)
  - Public IP address
  - HTTP load balancing rule (port 80)
  - Health probe monitoring
  - Backend pool with 2 web VMs

### Automation
- **Automation Account** (`aa-demo1-startstop`)
  - PowerShell runbooks for VM start/stop operations
  - Automated schedules:
    - **Start VMs**: 8:00 AM AST (Mon-Fri)
    - **Stop VMs**: 5:00 PM AST (Mon-Fri)
  - Saves ~60% on compute costs by running VMs only during business hours

## 🛠️ Requirements

### Tools & Software
- **Terraform** >= 1.5.0 (workflow uses v1.9.0)
- **Azure CLI** (for local development and authentication)
- **Git** (for version control)

### Azure Requirements
- Active Azure Subscription with permissions to create resources
- Azure Service Principal with:
  - **Contributor** role
  - **User Access Administrator** role (for automation account)

### GitHub Requirements
- GitHub Account with access to GitHub Actions
- Repository Secrets configured (see setup section below)

## 🚀 Setup Instructions

### 1. Azure Service Principal Setup

Create a service principal with required permissions:

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "github-terraform-sp" \
  --role "Contributor" \
  --scopes "/subscriptions/<YOUR_SUBSCRIPTION_ID>" \
  --sdk-auth

# Note: --sdk-auth is deprecated but still works. Save the JSON output!

# Grant User Access Administrator role (required for automation account)
az role assignment create \
  --assignee <CLIENT_ID_FROM_OUTPUT> \
  --role "User Access Administrator" \
  --scope "/subscriptions/<YOUR_SUBSCRIPTION_ID>"
```

**Important**: Save the entire JSON output from the first command - you'll need it for GitHub Secrets.

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

Create these two secrets:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AZURE_CREDENTIALS` | JSON output from service principal creation | `{"clientId": "xxx", "clientSecret": "xxx", ...}` |
| `VM_ADMIN_PASSWORD` | Password for VM administrator account | `YourSecureP@ssw0rd!` |

**Note**: VM password must meet Azure complexity requirements (12+ chars, uppercase, lowercase, number, special character).

### 3. Clone the Repository

```bash
git clone <your-repo-url>
cd <your-repo-name>
```

## 📖 Usage

### Option 1: Automated Deployment via GitHub Actions

#### Deploy Infrastructure

The workflow is triggered manually via GitHub UI:

To manually deploy:

1. Go to **Actions** tab in GitHub
2. Select **Deploy to Azure with Terraform** workflow
3. Click **Run workflow**
4. Select branch: `main`
5. Choose action: **deploy**
6. Click **Run workflow**

#### Destroy Infrastructure

To manually destroy:

1. Go to **Actions** tab in GitHub
2. Select **Deploy to Azure with Terraform** workflow
3. Click **Run workflow**
4. Select branch: `main`
5. Choose action: **destroy**
6. Click **Run workflow**

### Option 2: Local Deployment with Terraform CLI

#### Prerequisites for Local Use

1. **Authenticate with Azure**:
   ```bash
   az login
   ```

2. **Set environment variables** (use values from your `AZURE_CREDENTIALS` secret):
   ```bash
   export ARM_SUBSCRIPTION_ID="<subscription-id>"
   export ARM_TENANT_ID="<tenant-id>"
   export ARM_CLIENT_ID="<client-id>"
   export ARM_CLIENT_SECRET="<client-secret>"
   export TF_VAR_admin_password="<your-vm-password>"
   ```

#### Deploy Locally

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Deploy infrastructure
terraform apply
# Type 'yes' when prompted

# View outputs
terraform output
```

#### Destroy Locally

```bash
terraform destroy
# Type 'yes' when prompted
```

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions workflow
├── runbooks/
│   ├── start_vm.ps1           # PowerShell script to start VMs
│   └── stop_vm.ps1            # PowerShell script to stop VMs
├── .gitignore                 # Git ignore rules
├── main.tf                    # Terraform configuration
└── README.md                  # This file
```

## 🌐 Accessing Your Deployment

After successful deployment, Terraform outputs will show:

```
Outputs:

load_balancer_url = "http://xx.xx.xx.xx"
standalone_vm_public_ip = "xx.xx.xx.xx"
web_vm_names = ["vm-web-1", "vm-web-2"]
automation_account_name = "aa-demo1-startstop"
```

### Test the Load-Balanced Web Application

Visit the `load_balancer_url` in your browser:
```
http://<load_balancer_ip>
```

You should see: **"Hello World from VM 1"** or **"VM 2"**

**Note**: Due to browser connection reuse, you may need to use different browsers, incognito windows, or `curl` to see traffic distributed between both VMs:

```bash
curl http://<load_balancer_ip>
curl http://<load_balancer_ip>
curl http://<load_balancer_ip>
```

## 🔒 State Management

The GitHub Actions workflow uses **GitHub Artifacts** to store Terraform state between runs:

- State is uploaded after successful apply operations
- State is downloaded at the beginning of each workflow run
- State files are retained for 90 days

⚠️ **Note**: This approach is suitable for demos and testing. For production environments, use:
- [Azure Storage Backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Terraform Cloud](https://www.terraform.io/cloud)

## ⚙️ Configuration

### Modify Infrastructure

To customize the deployment, edit `main.tf`:

#### Change Region
```hcl
locals {
  location = "East US 2"  # Change to your preferred region
  rg_name  = "demo1"
}
```

#### Change VM Size
```hcl
locals {
  common_vm_config = {
    size = "Standard_D2s_v3"  # Change to desired VM size
    ...
  }
}
```

#### Change Number of Web VMs
```hcl
locals {
  web_vm_count = 3  # Change from 2 to desired number
  ...
}
```

#### Change Automation Schedule
```hcl
locals {
  schedules = {
    start = { time = "08:00", description = "Start at 8 AM" }
    stop  = { time = "17:00", description = "Stop at 5 PM" }
  }
}
```

Change timezone:
```hcl
timezone = "America/Puerto_Rico"  # Change to your timezone
```

[See available timezones](https://docs.microsoft.com/en-us/rest/api/maps/timezone/gettimezonebyid)

### Modify Terraform Version

Edit `.github/workflows/deploy.yml`:

```yaml
terraform_version: 1.9.0   # Change this version
```

## 🔍 Monitoring Deployments

### GitHub Actions
1. Go to the **Actions** tab in your GitHub repository
2. Click on the latest workflow run
3. Expand the steps to view detailed logs
4. Check for any errors or warnings

### Azure Portal
1. Navigate to **Resource Groups** → **demo1**
2. Review all deployed resources
3. Check **Automation Account** → **Jobs** to view scheduled start/stop history
4. Monitor **Load Balancer** → **Backend pools** for VM health status

## 💰 Cost Optimization

The automation account automatically manages VM runtime:

| Schedule | Action | Days |
|----------|--------|------|
| 8:00 AM AST | Start all VMs | Monday - Friday |
| 5:00 PM AST | Stop all VMs | Monday - Friday |
| All day | VMs remain off | Saturday - Sunday |

**Estimated monthly savings**: ~60% reduction in compute costs compared to 24/7 operation.

**Approximate costs** (East US region):
- 3x Standard_D2s_v3 VMs (9 hours/day, 5 days/week): ~$120-150/month
- Load Balancer: ~$20-25/month
- Storage: ~$5-10/month
- **Total**: ~$145-185/month

*Costs may vary by region and actual usage.*

## 🧹 Cleanup

### Complete Infrastructure Removal

**Option 1**: Via GitHub Actions (Recommended)
1. Run the **destroy** workflow as described above
2. Verify in Azure Portal that resource group is deleted

**Option 2**: Via Terraform CLI
```bash
terraform destroy
```

**Option 3**: Via Azure Portal
1. Navigate to **Resource Groups**
2. Select **demo1**
3. Click **Delete resource group**
4. Type the resource group name to confirm
5. Click **Delete**

### Clean Up Service Principal (Optional)

After destroying infrastructure, you can optionally remove the service principal:

```bash
az ad sp delete --id <client-id>
```

## ⚠️ Important Notes

- The workflow must be triggered manually from the GitHub Actions UI
- State files are stored as GitHub Artifacts (suitable for testing, not production)
- Ensure Azure subscription has sufficient quota for resources
- VM passwords must meet Azure complexity requirements
- Always review the plan output before applying changes
- The automation account requires "User Access Administrator" role
- Load balancer uses connection-based distribution (browser sessions may stick to one VM)

## 🐛 Troubleshooting

### Common Issues

**Issue**: Authorization failed when creating role assignments
```
Solution: Grant "User Access Administrator" role to service principal
```

**Issue**: VM allocation failed - insufficient capacity
```
Solution: Try different VM size or region in main.tf
```

**Issue**: Load balancer shows unhealthy VMs
```
Solution: Check NSG rules, verify IIS is running on VMs
```

**Issue**: Automation schedules not running
```
Solution: Verify automation account identity has VM Contributor role
```

## 📚 Additional Resources

- [Azure Terraform Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Load Balancer Documentation](https://docs.microsoft.com/en-us/azure/load-balancer/)
- [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

**Questions or Issues?** Open an issue in this repository.