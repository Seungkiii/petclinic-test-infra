# =============================================================================
# Security Groups Module 호출
# =============================================================================

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  name_prefix              = local.name_prefix
  allowed_ssh_cidr         = var.allowed_ssh_cidr
  app_private_subnet_cidrs = var.app_private_subnet_cidrs

  # Tags
  bastion_sg_tags     = local.sg_tags["bastion"]
  mgmt_sg_tags        = local.sg_tags["mgmt"]
  rds_sg_tags         = local.sg_tags["rds"]
  eks_cluster_sg_tags = local.sg_tags["eks_cluster"]
}
