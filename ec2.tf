# =============================================================================
# EC2 Module 호출
# =============================================================================

module "ec2" {
  source = "./modules/ec2"

  name_prefix                    = local.name_prefix
  common_tags                    = local.common_tags
  key_name                       = var.key_name
  key_output_path                = "${path.module}/mykey"
  ec2_ami_id                     = var.ec2_ami_id
  ubuntu_ami_id                  = data.aws_ami.ubuntu.id
  bastion_instance_type          = var.bastion_instance_type
  mgmt_instance_type             = var.mgmt_instance_type
  bastion_volume_size            = 20
  mgmt_volume_size               = 50
  public_subnet_ids              = module.vpc.public_subnet_ids
  app_private_subnet_ids         = module.vpc.app_private_subnet_ids
  bastion_sg_id                  = module.security_groups.bastion_sg_id
  mgmt_sg_id                     = module.security_groups.mgmt_sg_id
  mgmt_iam_instance_profile_name = aws_iam_instance_profile.mgmt_server.name
  bastion_tags                   = local.bastion_tags
  mgmt_tags                      = local.mgmt_tags

  # User Data
  bastion_user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # 시스템 업데이트
    apt-get update -y
    apt-get upgrade -y
    
    # 기본 도구 설치
    apt-get install -y vim htop curl wget unzip
    
    echo "Bastion host initialization completed!" >> /var/log/user-data.log
  EOF

  mgmt_user_data = templatefile("${path.module}/user_data_mgmt.sh", {
    aws_region       = var.aws_region
    eks_cluster_name = var.eks_cluster_name
    db_endpoint      = "" # RDS 생성 후 업데이트됨
    db_username      = var.db_username
    db_password      = var.db_password
  })

  nat_gateway_dependency = module.vpc.nat_gateway_ids
}
