output "configuration" {
  description = "Echoes the requested RDS configuration for validation/testing"
  value = {
    db_name           = var.db_name
    engine            = var.engine
    engine_version    = var.engine_version
    instance_class    = var.instance_class
    storage_encrypted = var.storage_encrypted
    multi_az          = var.multi_az
    tags              = local.normalized_tags
  }
}
