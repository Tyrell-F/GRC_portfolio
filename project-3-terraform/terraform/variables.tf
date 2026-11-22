variable "location" {
  description = "Azure region for every resource. POAM-10: the resource group and its resources share one region."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group for the rebuilt system."
  type        = string
  default     = "rg-grc-tf"
}

variable "vnet_cidr" {
  description = "Address space for the virtual network."
  type        = string
  default     = "10.10.0.0/16"
}

variable "vm_size" {
  description = "VM size. Fallback if West US 2 is out of capacity: Standard_B2ts_v2 (RA-03)."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "admin_username" {
  description = "Local admin account on the VM (SSH key only)."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the admin account. Set it in terraform.tfvars, which Git ignores."
  type        = string
}

variable "alert_email" {
  description = "Email address that receives alert notifications. Set it in terraform.tfvars, which Git ignores."
  type        = string
}

variable "enable_nat" {
  description = "Session-only outbound internet for patching. Turn on for admin sessions, off afterward (cost)."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Session-only Azure Bastion (Basic) for interactive SSH. Off by default (cost)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource (CM-8 inventory)."
  type        = map(string)
  default = {
    system      = "vm-grc-01"
    environment = "lab"
    owner       = "tyrell"
    managed_by  = "terraform"
  }
}
