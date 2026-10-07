module "postgres-flexible-db" {
    count = var.op_mode == "enterprise" ? 1 : 0
    source = "../postgres-flexible-db"
    application_name = var.application_name
    application_private_ip = var.application_private_ip
    db_name = var.db_name
    db_subnet_cidr_block = var.db_subnet_cidr_block
    psql_admin = var.psql_admin
    psql_password = var.psql_password
    rg_name = var.rg_name
    vn_id = var.vn_id
    vn_location = var.vn_location
    vn_name = var.vn_name
}

module "postgres-vm-db" {
    count = var.op_mode == "development" ? 1 : var.op_mode == "regular" ? 1 : 0
    monitoring_ip = var.monitoring_ip
    source = "../postgres-vm-db"
    application_private_ip = var.application_private_ip
    application_name = var.application_name
    db_subnet_cidr_block = var.db_subnet_cidr_block
    db_name = var.db_name
    linux_admin = var.linux_admin
    my_ip = var.my_ip
    psql_admin = var.psql_admin
    psql_password = var.psql_password
    rg_name = var.rg_name
    ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path
    vn_location = var.vn_location
    vn_name = var.vn_name
    spot_instance = var.op_mode == "development" ? true : false
}

