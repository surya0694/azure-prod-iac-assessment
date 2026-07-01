variable "project_name" {
  description = "Short project name used for Azure resource naming."
  type        = string
  default     = "prod-iac"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,18}$", var.project_name))
    error_message = "project_name must be 3-18 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Linux VM admin username."
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "Public SSH key for the Linux VM admin user. Pass with TF_VAR_admin_ssh_public_key."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be a valid OpenSSH public key beginning with ssh-rsa or ssh-ed25519."
  }
}

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "web_subnet_prefixes" {
  description = "CIDR prefixes for the web subnet."
  type        = list(string)
  default     = ["10.40.1.0/24"]
}

variable "allowed_https_cidrs" {
  description = "CIDR blocks allowed to access the public HTTPS service. For stricter security, replace 0.0.0.0/0 with trusted office/VPN IPs."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the VM. Leave empty to disable public SSH. Example: [\"203.0.113.10/32\"]."
  type        = list(string)
  default     = []
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "alert_email" {
  description = "Optional email address for Azure Monitor action group notifications. Leave empty to create the alert without email receivers."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    workload   = "assessment"
  }
}
