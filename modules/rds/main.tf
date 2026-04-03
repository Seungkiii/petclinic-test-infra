locals {
  normalized_tags = merge(
    {
      ManagedBy = lookup(var.tags, "ManagedBy", "Terraform")
    },
    var.tags
  )
}
