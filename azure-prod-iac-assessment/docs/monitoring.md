# Monitoring and Alerting Notes

## Implemented alert

Terraform creates one Azure Monitor metric alert:

- Name: Terraform output `vm_availability_alert_name`
- Scope: Linux VM
- Metric namespace: `Microsoft.Compute/virtualMachines`
- Metric: `VmAvailabilityMetric`
- Aggregation: `Average`
- Window: 5 minutes
- Frequency: 1 minute
- Trigger: value less than `1`
- Action group: optional email receiver if `alert_email` is supplied

## Why this alert is meaningful

`VmAvailabilityMetric` is an Azure platform metric that measures VM availability over time. For this assessment, it is more directly tied to workload health than a simple CPU alert because the service depends on the VM being available. If the VM becomes unavailable, the HTTPS service will also be unavailable.

## How to test manually

```bash
RG="$(terraform output -raw resource_group_name)"
VM="$(terraform output -raw vm_name)"
VM_ID="$(az vm show -g "$RG" -n "$VM" --query id -o tsv)"

az monitor metrics list \
  --resource "$VM_ID" \
  --metric "VmAvailabilityMetric" \
  --interval PT1M \
  --aggregation Average \
  -o table
```

To simulate a VM outage for alert testing, stop the VM:

```bash
az vm deallocate --resource-group "$RG" --name "$VM"
```

After testing, start it again:

```bash
az vm start --resource-group "$RG" --name "$VM"
```

## Operational dashboard checks

For a small production service, monitor these checks:

1. VM availability: `VmAvailabilityMetric`
2. Public endpoint response: `curl -k https://<public-ip>/healthz`
3. nginx service status: `systemctl status nginx`
4. Key Vault secret expiry: review secret `expires` attributes during rotation
5. NSG drift: confirm only expected inbound rules exist

## Recommended future improvements

- Put the VM behind Application Gateway or Azure Front Door and use a managed TLS certificate.
- Add a Log Analytics workspace and Azure Monitor Agent for guest OS logs and memory/disk metrics.
- Add an Application Insights or Azure Load Testing availability test for HTTPS endpoint monitoring.
- Add Key Vault diagnostic settings and alert on failed/denied secret access spikes.
- Move Terraform state to an Azure Storage backend with state locking for team use.
