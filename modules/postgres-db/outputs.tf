output "db-private-ip" {
  value =  length(module.postgres-vm-db) != 0 ? module.postgres-vm-db[0].db-vm-private_ip : ""
}

output "postgres-flexible-server-id" {
  value = length(module.postgres-flexible-db) != 0 ? module.postgres-flexible-db[0].postgres-db-server-id : ""
}