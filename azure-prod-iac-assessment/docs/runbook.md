# Operational Runbook

Audience: Azure or platform engineers who need to deploy, verify, operate, or recover this workload without having built it.

## 1. System overview

This workload is a single Linux VM running nginx over HTTPS. Terraform provisions the Azure network, VM, Key Vault, access policies, cloud-init bootstrap, and a VM availability alert.

Core resources:

- Resource group: output `resource_group_name`
- VM: output `vm_name`
- HTTPS endpoint: output `https_url`
- Key Vault: output `key_vault_name`
- Alert rule: output `vm_availability_alert_name`

## 2. Deploy from scratch

### 2.1 Required access

You need an Azure identity with permission to create:

- Resource groups
- Virtual networks, subnets, NSGs, public IPs, and NICs
- Linux virtual machines and managed identities
- Key Vaults and Key Vault access policies
- Azure Monitor action groups and metric alerts

### 2.2 Login and set subscription

```bash
az login
az account set --subscription "<subscription-id>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
```

### 2.3 Configure variables

```bash
cd terraform
export TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/azure_iac_assessment.pub)"
export TF_VAR_allowed_ssh_cidrs='["<your-public-ip>/32"]'
export TF_VAR_allowed_https_cidrs='["0.0.0.0/0"]'
export TF_VAR_alert_email="you@example.com"
```

For production, replace `0.0.0.0/0` with trusted CIDR ranges or place the VM behind approved ingress such as Application Gateway or Azure Firewall.

### 2.4 Deploy

```bash
terraform init
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Record these outputs:

```bash
terraform output resource_group_name
terraform output vm_name
terraform output key_vault_name
terraform output https_url
```

## 3. Health verification

### 3.1 HTTPS health endpoint

```bash
curl -k "$(terraform output -raw https_url)"
```

Expected response:

```text
ok
```

You can also run:

```bash
../scripts/health-check.sh "$(terraform output -raw https_url)"
```

### 3.2 Azure VM power and provisioning state

```bash
RG="$(terraform output -raw resource_group_name)"
VM="$(terraform output -raw vm_name)"
az vm get-instance-view \
  --resource-group "$RG" \
  --name "$VM" \
  --query "instanceView.statuses[].{code:code,displayStatus:displayStatus}" \
  -o table
```

Expected state includes `PowerState/running`.

### 3.3 SSH and service check

Only works if `allowed_ssh_cidrs` includes your current public IP.

```bash
IP="$(terraform output -raw public_ip_address)"
ssh -i ~/.ssh/azure_iac_assessment azureadmin@"$IP"
```

On the VM:

```bash
sudo systemctl status nginx --no-pager
sudo nginx -t
curl -k https://localhost/healthz
sudo journalctl -u nginx --since "30 minutes ago" --no-pager
sudo tail -n 100 /var/log/cloud-init-output.log
```

## 4. Key Vault secret rotation

This sample does not hardcode application secrets. Use this process when a runtime secret needs rotation.

### 4.1 Create or rotate a secret

```bash
KV="$(terraform output -raw key_vault_name)"
az keyvault secret set \
  --vault-name "$KV" \
  --name "app-config" \
  --value "<new-secret-value>" \
  --expires "$(date -u -d '+90 days' '+%Y-%m-%dT%H:%M:%SZ')"
```

On macOS, replace the `date` command with:

```bash
EXPIRY="$(date -u -v+90d '+%Y-%m-%dT%H:%M:%SZ')"
az keyvault secret set --vault-name "$KV" --name "app-config" --value "<new-secret-value>" --expires "$EXPIRY"
```

### 4.2 Verify the new version

```bash
az keyvault secret show \
  --vault-name "$KV" \
  --name "app-config" \
  --query "{name:name, id:id, enabled:attributes.enabled, expires:attributes.expires}" \
  -o table
```

### 4.3 Application follow-up

If a future application reads secrets at startup only, restart that application after rotation. For the current nginx sample, there is no application secret dependency, so no restart is required.

## 5. Recovery from VM failure

Use this order: confirm impact, attempt restart, inspect bootstrap logs, then recreate using Terraform if needed.

### 5.1 Confirm impact

```bash
curl -k "$(terraform output -raw https_url)"
az monitor metrics list \
  --resource "$(az vm show -g "$(terraform output -raw resource_group_name)" -n "$(terraform output -raw vm_name)" --query id -o tsv)" \
  --metric "VmAvailabilityMetric" \
  --interval PT1M \
  --aggregation Average \
  -o table
```

### 5.2 Restart the VM

```bash
RG="$(terraform output -raw resource_group_name)"
VM="$(terraform output -raw vm_name)"
az vm restart --resource-group "$RG" --name "$VM"
```

Recheck:

```bash
curl -k "$(terraform output -raw https_url)"
```

### 5.3 Review boot diagnostics and cloud-init

If SSH works:

```bash
ssh azureadmin@"$(terraform output -raw public_ip_address)"
sudo tail -n 200 /var/log/cloud-init-output.log
sudo systemctl status nginx --no-pager
sudo nginx -t
```

If SSH does not work, use Azure Portal boot diagnostics or serial console for the VM.

### 5.4 Recreate the VM with Terraform

The app has no local persistent data. Recreating the VM is safe for this sample.

```bash
terraform plan -replace=azurerm_linux_virtual_machine.web -out replace-vm.tfplan
terraform apply replace-vm.tfplan
```

Then verify:

```bash
../scripts/health-check.sh "$(terraform output -raw https_url)"
```

### 5.5 Recreate networking only if needed

If the NIC or public IP is corrupted or manually changed, run a normal plan first:

```bash
terraform plan
```

Only use targeted replacement when the plan clearly shows the dependency chain and expected impact.

## 6. Common issues

| Symptom | Likely cause | Action |
|---|---|---|
| `curl -k` times out | NSG source CIDR does not allow your IP | Update `allowed_https_cidrs` and run `terraform apply` |
| SSH fails | `allowed_ssh_cidrs` is empty or wrong | Add your `/32` public IP and apply |
| Browser warning on HTTPS | Self-signed certificate | Expected for this assessment; use `curl -k` |
| Key Vault destroy leaves deleted vault | Purge protection and soft delete | Expected production control; wait retention period or use a different project suffix |
| nginx not running | cloud-init/bootstrap issue | Check `/var/log/cloud-init-output.log`, then rerun or recreate VM |
