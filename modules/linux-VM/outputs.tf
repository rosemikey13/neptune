output "application_private_ip_address" {
  value = azurerm_network_interface.application_ni.private_ip_address
}

output "application_public_ip_address" {
  value = azurerm_public_ip.application_public_ip.ip_address
}

output "application_name" {
  value = var.application_name
}