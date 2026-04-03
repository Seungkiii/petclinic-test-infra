variable "db_name" {
  description = "Database name"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "storage_encrypted" {
  description = "Whether storage encryption is enabled"
  type        = bool
}

variable "multi_az" {
  description = "Whether Multi-AZ deployment is enabled"
  type        = bool
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
