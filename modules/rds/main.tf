# RDS Module - Main (full production-grade config)
# See variables.tf for all inputs and outputs.tf for all outputs

locals {
  name_prefix            = "${var.project}-${var.environment}"
  engine_version         = var.engine_version != null ? var.engine_version : (var.engine == "mysql" ? "8.0" : "15")
  parameter_group_family = var.parameter_group_family != null ? var.parameter_group_family : (var.engine == "mysql" ? "mysql8.0" : "postgres15")
  cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports != null ? var.enabled_cloudwatch_logs_exports : (var.engine == "mysql" ? ["general", "error", "slowquery"] : ["postgresql", "upgrade"])
  db_port                = var.engine == "mysql" ? 3306 : 5432
  final_snapshot_id      = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : (var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot")
  common_tags = merge({ Environment = var.environment; Project = var.project; Module = "rds"; ManagedBy = "Terraform" }, var.tags)
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-${var.identifier}-subnet-group" })
}

resource "aws_security_group" "rds" {
  name   = "${local.name_prefix}-${var.identifier}-sg"
  vpc_id = var.vpc_id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-${var.identifier}-sg" })
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "cidr_ingress" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = local.db_port
  to_port           = local.db_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.rds.id
}

resource "aws_security_group_rule" "sg_ingress" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = local.db_port
  to_port                  = local.db_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.rds.id
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.name_prefix}-${var.identifier}-params"
  family = local.parameter_group_family
  dynamic "parameter" {
    for_each = var.parameters
    content { name = parameter.value.name; value = parameter.value.value; apply_method = parameter.value.apply_method }
  }
  tags      = merge(local.common_tags, { Name = "${local.name_prefix}-${var.identifier}-params" })
  lifecycle { create_before_destroy = true }
}

resource "aws_db_option_group" "this" {
  count                    = var.engine == "mysql" ? 1 : 0
  name                     = "${local.name_prefix}-${var.identifier}-options"
  option_group_description = "Option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = split(".", local.engine_version)[0]
  dynamic "option" {
    for_each = var.options
    content {
      option_name = option.value.option_name
      dynamic "option_settings" {
        for_each = option.value.option_settings
        content { name = option_settings.value.name; value = option_settings.value.value }
      }
    }
  }
  tags      = merge(local.common_tags, { Name = "${local.name_prefix}-${var.identifier}-options" })
  lifecycle { create_before_destroy = true }
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${local.name_prefix}-${var.identifier}-monitoring-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17"; Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"; Principal = { Service = "monitoring.rds.amazonaws.com" } }] })
  tags  = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "primary" {
  identifier                            = var.identifier
  engine                                = var.engine
  engine_version                        = local.engine_version
  instance_class                        = var.instance_class
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type                          = var.storage_type
  storage_encrypted                     = var.storage_encrypted
  kms_key_id                            = var.kms_key_id
  db_name                               = var.db_name
  username                              = var.master_username
  password                              = var.master_password
  port                                  = local.db_port
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  vpc_security_group_ids                = [aws_security_group.rds.id]
  publicly_accessible                   = var.publicly_accessible
  multi_az                              = var.multi_az
  backup_retention_period               = var.backup_retention_period
  backup_window                         = var.backup_window
  copy_tags_to_snapshot                 = var.copy_tags_to_snapshot
  delete_automated_backups              = var.delete_automated_backups
  final_snapshot_identifier             = var.skip_final_snapshot ? null : local.final_snapshot_id
  skip_final_snapshot                   = var.skip_final_snapshot
  maintenance_window                    = var.maintenance_window
  auto_minor_version_upgrade            = var.auto_minor_version_upgrade
  apply_immediately                     = var.apply_immediately
  parameter_group_name                  = aws_db_parameter_group.this.name
  option_group_name                     = var.engine == "mysql" ? aws_db_option_group.this[0].name : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  enabled_cloudwatch_logs_exports       = local.cloudwatch_logs_exports
  deletion_protection                   = var.deletion_protection
  tags                                  = merge(local.common_tags, { Name = "${local.name_prefix}-${var.identifier}"; Role = "primary" })
}

resource "aws_db_instance" "replica" {
  count                  = var.create_read_replica ? 1 : 0
  identifier             = "${var.identifier}-replica"
  replicate_source_db    = aws_db_instance.primary.identifier
  instance_class         = coalesce(var.read_replica_instance_class, var.instance_class)
  publicly_accessible    = var.publicly_accessible
  vpc_security_group_ids = [aws_security_group.rds.id]
  backup_retention_period = 0
  skip_final_snapshot    = true
  monitoring_interval    = var.monitoring_interval
  monitoring_role_arn    = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately      = var.apply_immediately
  tags                   = merge(local.common_tags, { Name = "${local.name_prefix}-${var.identifier}-replica"; Role = "replica" })
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-${var.identifier}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is above 80%"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.primary.identifier }
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "free_storage_low" {
  alarm_name          = "${local.name_prefix}-${var.identifier}-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120
  alarm_description   = "RDS free storage space is below 5GB"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.primary.identifier }
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "db_connections_high" {
  alarm_name          = "${local.name_prefix}-${var.identifier}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "RDS database connections exceeded 100"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.primary.identifier }
  tags                = local.common_tags
}
