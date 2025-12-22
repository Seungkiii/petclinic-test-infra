# =============================================================================
# SSM Parameters & Secrets Manager Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# EKS Optimized Amazon Linux 2023 AMI (x86_64)
# -----------------------------------------------------------------------------
# Uses AWS-owned EKS optimized AMI catalog
# Reference: amazon-eks-node-al2023-x86_64-standard-*
# -----------------------------------------------------------------------------

data "aws_ami" "eks_al2023" {
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------------------------------------------------------------
# Secrets Manager: DB Credentials (shared across services)
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "petclinic_db_credentials" {
  name = "/petclinic/db_credentials"
}

resource "aws_secretsmanager_secret_version" "petclinic_db_credentials" {
  secret_id = aws_secretsmanager_secret.petclinic_db_credentials.id
  secret_string = jsonencode({
    CUSTOMERS_DATASOURCE_USERNAME = var.db_username
    CUSTOMERS_DATASOURCE_PASSWORD = var.db_password
    VETS_DATASOURCE_USERNAME      = var.db_username
    VETS_DATASOURCE_PASSWORD      = var.db_password
    VISITS_DATASOURCE_USERNAME    = var.db_username
    VISITS_DATASOURCE_PASSWORD    = var.db_password
  })
}

# -----------------------------------------------------------------------------
# SSM Parameters (Standard Tier)
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "petclinic_db_host" {
  name  = "/petclinic/db_host"
  type  = "String"
  tier  = "Standard"
  value = aws_db_instance.main.endpoint
}

resource "aws_ssm_parameter" "petclinic_vpc_id" {
  name  = "/petclinic/vpc_id"
  type  = "String"
  tier  = "Standard"
  value = module.vpc.vpc_id
}

resource "aws_ssm_parameter" "petclinic_private_subnets" {
  name  = "/petclinic/subnets/private"
  type  = "StringList"
  tier  = "Standard"
  value = join(",", module.vpc.app_private_subnet_ids)
}

resource "aws_ssm_parameter" "petclinic_public_subnets" {
  name  = "/petclinic/subnets/public"
  type  = "StringList"
  tier  = "Standard"
  value = join(",", module.vpc.public_subnet_ids)
}

resource "aws_ssm_parameter" "petclinic_karpenter_role_arn" {
  name  = "/petclinic/karpenter/role_arn"
  type  = "String"
  tier  = "Standard"
  value = module.karpenter.role_arn
}

resource "aws_ssm_parameter" "petclinic_karpenter_ami_id" {
  name  = "/petclinic/karpenter/ami_id"
  type  = "String"
  tier  = "Standard"
  value = data.aws_ami.eks_al2023.id
}

resource "aws_ssm_parameter" "petclinic_aws_account_id" {
  name  = "/petclinic/aws_account_id"
  type  = "String"
  tier  = "Standard"
  value = data.aws_caller_identity.current.account_id
}
