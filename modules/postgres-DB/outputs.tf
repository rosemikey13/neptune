output "postgres-db-server_id" {
  value = azurerm_postgresql_flexible_server.application_db_server.id
}

output "postgres-db-server-name" {
  value = azurerm_postgresql_flexible_server.application_db_server.name
}