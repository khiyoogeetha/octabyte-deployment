resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.private_subnets
  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "${var.project_name}-${var.environment}-db"
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "15" # Major version only, AWS will auto-select the latest supported minor version
  instance_class       = "db.t3.micro" # Free tier eligible for assignment cost saving
  db_name              = "devopsdb"
  username             = "dbadmin"
  password             = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.db_sg_id]

  skip_final_snapshot    = true # Important for easy destruction during assignment
  publicly_accessible    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}
