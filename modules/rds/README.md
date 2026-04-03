# Reusable RDS Module Scaffold

This module is a lightweight scaffold intended for validation and testing of Git-based Terraform module sourcing.

## Inputs

- `db_name`
- `engine`
- `engine_version`
- `instance_class`
- `storage_encrypted`
- `multi_az`
- `tags`

## Example

```hcl
module "rds_postgres" {
  source            = "git::https://github.com/Seungkiii/petclinic-test-infra.git//modules/rds?ref=main"
  db_name           = "reservationdb"
  engine            = "postgres"
  engine_version    = "14.7"
  instance_class    = "db.m5.large"
  storage_encrypted = true
  multi_az          = true

  tags = {
    Environment = "Prod"
    Team        = "AppTeam"
    Service     = "Reservation"
    ManagedBy   = "Terraform"
  }
}
```

## Notes

This scaffold intentionally contains no AWS resources yet. It is designed to make `terraform init` and `terraform validate` succeed when testing PR-based GitOps pipelines before the real RDS implementation is added.
