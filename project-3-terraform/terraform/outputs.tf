output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "key_vault_private_ip" {
  value = azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "disk_encryption_set_id" {
  value = azurerm_disk_encryption_set.des.id
}
