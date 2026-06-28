variable "identifier"   { description = "Unique identifier for the RDS instance"; type = string }
variable "environment"  { description = "Deployment environment (dev, staging, prod)"; type = string; validation { condition = contains(["dev","staging","prod"], var.environment); error_message = "Must be dev, staging, or prod." } }
variable "project"      { description = "Project name for tagging and naming"; type = string }
variable "tags"         { description = "Additional tags"; type = map(string); default = {} }

variable "engine"         { description = "Database engine: mysql or postgres"; type = string; default = "mysql"; validation { condition = contains(["mysql","postgres"], var.engine); error_message = "Must be mysql or postgres." } }
variable "engine_version" { description = "Engine version (auto-derived if null)"; type = string; default = null }
variable "instance_class" { description = "RDS instance class"; type = string; default = "db.t3.small" }

variable "allocated_storage"     { description = "Initial storage in GB"; type = number; default = 20 }
variable "max_allocated_storage" { description = "Max storage for autoscaling in GB (0 = disabled)"; type = number; default = 100 }
variable "storage_type"          { description = "Storage type: gp2, gp3, io1"; type = string; default = "gp3" }
variable "iops"                  { description = "IOPS for io1 storage"; type = number; default = null }
variable "storage_encrypted"     { description = "Enable storage encryption"; type = bool; default = true }
variable "kms_key_id"            { description = "ARN of KMS key (uses AWS default if null)"; type = string; default = null }

variable "db_name"         { description = "Name of the initial database"; type = string }
variable "master_username" { description = "Master username"; type = string; sensitive = true }
variable "master_password" { description = "Master password"; type = string; sensitive = true }

variable "vpc_id"                     { description = "VPC ID"; type = string }
variable "subnet_ids"                 { description = "List of private subnet IDs (min 2 for Multi-AZ)"; type = list(string) }
variable "allowed_cidr_blocks"        { description = "CIDR blocks allowed to connect"; type = list(string); default = [] }
variable "allowed_security_group_ids" { description = "Security group IDs allowed to connect"; type = list(string); default = [] }
variable "publicly_accessible"        { description = "Make RDS publicly accessible"; type = bool; default = false }

variable "multi_az"                   { description = "Enable Multi-AZ"; type = bool; default = true }
variable "create_read_replica"        { description = "Create a read replica"; type = bool; default = false }
variable "read_replica_instance_class" { description = "Read replica instance class"; type = string; default = null }

variable "backup_retention_period" { description = "Days to retain backups (0-35)"; type = number; default = 7 }
variable "backup_window"           { description = "Daily backup window (UTC)"; type = string; default = "03:00-04:00" }
variable "maintenance_window"      { description = "Weekly maintenance window"; type = string; default = "Mon:04:00-Mon:05:00" }
variable "delete_automated_backups" { description = "Delete automated backups on instance deletion"; type = bool; default = true }
variable "copy_tags_to_snapshot"   { description = "Copy tags to snapshots"; type = bool; default = true }
variable "final_snapshot_identifier" { description = "Final snapshot name on deletion"; type = string; default = null }
variable "skip_final_snapshot"     { description = "Skip final snapshot on deletion"; type = bool; default = false }

variable "monitoring_interval"                    { description = "Enhanced monitoring interval in seconds (0=disabled)"; type = number; default = 60 }
variable "performance_insights_enabled"           { description = "Enable Performance Insights"; type = bool; default = true }
variable "performance_insights_retention_period"  { description = "Performance Insights retention in days"; type = number; default = 7 }
variable "enabled_cloudwatch_logs_exports"        { description = "Log types to export to CloudWatch"; type = list(string); default = null }

variable "parameter_group_family" { description = "DB parameter group family (auto-derived if null)"; type = string; default = null }
variable "parameters" {
  description = "List of DB parameters"
  type = list(object({ name = string; value = string; apply_method = optional(string, "immediate") }))
  default = []
}
variable "options" {
  description = "List of option group options (MySQL only)"
  type = list(object({ option_name = string; option_settings = optional(list(object({ name = string; value = string })), []) }))
  default = []
}

variable "auto_minor_version_upgrade" { description = "Allow automatic minor version upgrades"; type = bool; default = true }
variable "deletion_protection"        { description = "Enable deletion protection"; type = bool; default = false }
variable "apply_immediately"          { description = "Apply changes immediately"; type = bool; default = false }
