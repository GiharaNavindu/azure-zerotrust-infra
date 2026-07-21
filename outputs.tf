output "jumpbox_public_ip" {
  value       = azurerm_public_ip.jumpbox_pip.ip_address
  description = "The public facing IPv4 address assigned to the management jumpbox node."
}