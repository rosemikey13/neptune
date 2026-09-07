output "db-vm-private_ip" {
  value = azurerm_network_interface.application_ni.private_ip_address
}

output "application-name" {
    value = var.application_name
}