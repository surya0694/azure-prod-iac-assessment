# Azure Production-Grade IaC Assessment

This repository deploys a small production-style Azure workload using Terraform. It provisions a Linux VM running an HTTPS nginx service, a virtual network with subnet-level NSG controls, an Azure Key Vault using access policies, and an Azure Monitor alert for VM availability.

The goal is to show hands-on Terraform, Azure fluency, CI/CD ownership, security awareness, observability, and operational documentation that another engineer can follow.

## Architecture

```text
Internet / approved CIDRs
        |
        | TCP/443 only
        v
Azure Public IP
        |
Network Interface
        |
Subnet: snet-web + NSG
        |
Linux VM: Ubuntu + nginx HTTPS service
        |
Managed Identity -> Key Vault access policy: secret Get only

Azure Monitor metric alert watches VmAvailabilityMetric for the VM.
```

## What gets deployed

| Area | Resource |
|---|---|
| Compute | Ubuntu Linux VM with system-assigned managed identity |
| Network | Resource group, VNet, web subnet, NSG, NIC, static Standard public IP |
| Security | Key Vault with access policies, VM managed identity with least-privilege secret read access, SSH key auth only |
| App bootstrap | cloud-init startup script installs nginx, creates a self-signed TLS certificate, and exposes `/healthz` over HTTPS |
| Observability | Azure Monitor metric alert on VM availability and optional email action group |
| CI/CD | GitHub Actions PR workflow for `terraform fmt`, `terraform init`, `terraform validate`, and TFLint |

## Repository layout

```text
.
├── .github/workflows/terraform-ci.yml   # PR validation/lint workflow
├── terraform/                           # Terraform root module
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── monitoring.tf
│   ├── outputs.tf
│   ├── cloud-init.yml.tftpl
│   └── terraform.tfvars.example
├── docs/
│   ├── runbook.md
│   ├── monitoring.md
│   └── ai-usage.md
├── scripts/health-check.sh
└── README.md
```

## Prerequisites

Install and configure:

- Azure CLI
- Terraform CLI 1.6 or newer
- An Azure subscription where you can create compute, network, Key Vault, and Azure Monitor resources
- An SSH key pair for VM access

Login to Azure:

```bash
az login
az account set --subscription "<subscription-id>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
```

Create an SSH key if you do not already have one:

```bash
ssh-keygen -t ed25519 -C "azure-iac-assessment" -f ~/.ssh/azure_iac_assessment
```

## Deploy from scratch

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and replace:

- `admin_ssh_public_key`
- `allowed_ssh_cidrs`
- `alert_email`, if you want email notification
- `location`, if needed

A safer way to pass the SSH key without committing it is:

```bash
export TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/azure_iac_assessment.pub)"
export TF_VAR_allowed_ssh_cidrs='["<your-public-ip>/32"]'
export TF_VAR_alert_email="you@example.com"
```

Then run:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

## Verify health

```bash
terraform output https_url
curl -k "$(terraform output -raw https_url)"
../scripts/health-check.sh "$(terraform output -raw https_url)"
```

Expected response:

```text
ok
```

The endpoint uses a self-signed certificate because this assessment does not provision a public DNS name or managed certificate. Use `curl -k` for validation.

## Destroy

```bash
terraform destroy
```

Important: Key Vault purge protection is enabled to model a production safety control. After destroy, the Key Vault name can remain reserved until its soft-delete retention period expires.

## Security notes

- No passwords are used for the VM. SSH key authentication is required.
- SSH is disabled by default because `allowed_ssh_cidrs` defaults to an empty list.
- HTTPS is allowed only from `allowed_https_cidrs`. The sample defaults to `0.0.0.0/0` so reviewers can test the service, but production should restrict this to trusted ingress ranges, VPN, Application Gateway, or a load balancer front end.
- Key Vault uses access policies. The VM managed identity receives only `Get` permission for secrets.
- Secrets are not hardcoded in Terraform. Pass sensitive inputs through environment variables, GitHub secrets, or a secure secret store.

## Monitoring summary

The deployment creates an Azure Monitor metric alert on the VM `VmAvailabilityMetric`. The alert fires when availability drops below `1` for a 5-minute window. See [docs/monitoring.md](docs/monitoring.md) for operational details.

## CI/CD summary

GitHub Actions runs on pull requests and pushes to `main`. It performs:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false`
3. `terraform validate`
4. `tflint --recursive`

The pipeline intentionally does not run `terraform plan` or `terraform apply` because public assessment repositories should not require Azure credentials for pull request validation.

## AI usage

See [docs/ai-usage.md](docs/ai-usage.md).
