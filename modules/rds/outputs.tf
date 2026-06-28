output "db_instance_id"       { value = aws_db_instance.primary.id }
output "db_instance_arn"      { value = aws_db_instance.primary.arn }
output "db_instance_endpoint" { value = aws_db_instance.primary.endpoint }
output "db_instance_port"     { value = aws_db_instance.primary.port }
output "db_subnet_group_name" { value = aws_db_subnet_group.this.name }
output "security_group_id"    { value = aws_security_group.rds.id }
output "replica_endpoint"     { value = try(aws_db_instance.replica[0].endpoint, null) }
