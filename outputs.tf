# =============================================================================
# Terraform Outputs
# 주요 리소스 접속 정보 및 참조 값 출력
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR Block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "app_private_subnet_ids" {
  description = "App Private Subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "db_private_subnet_ids" {
  description = "DB Private Subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "all_private_subnet_ids" {
  description = "All Private Subnet IDs (App + DB)"
  value       = concat(aws_subnet.private_app[*].id, aws_subnet.private_db[*].id)
}

output "nat_gateway_ips" {
  description = "NAT Gateway Public IPs (HA)"
  value       = aws_eip.nat[*].public_ip
}

# -----------------------------------------------------------------------------
# EC2 Outputs
# -----------------------------------------------------------------------------
output "bastion_public_ip" {
  description = "Bastion Host Public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Bastion Host Instance ID"
  value       = aws_instance.bastion.id
}

output "mgmt_server_private_ip" {
  description = "Management Server Private IP"
  value       = aws_instance.mgmt.private_ip
}

output "mgmt_server_instance_id" {
  description = "Management Server Instance ID"
  value       = aws_instance.mgmt.id
}

# -----------------------------------------------------------------------------
# RDS Outputs
# -----------------------------------------------------------------------------
output "rds_endpoint" {
  description = "RDS MySQL Endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS MySQL Address (without port)"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS MySQL Port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS Database Name"
  value       = aws_db_instance.main.db_name
}

# -----------------------------------------------------------------------------
# Security Group Outputs
# -----------------------------------------------------------------------------
output "sg_bastion_id" {
  description = "Bastion Security Group ID"
  value       = aws_security_group.bastion.id
}

output "sg_mgmt_id" {
  description = "Management Server Security Group ID"
  value       = aws_security_group.mgmt.id
}

output "sg_rds_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "sg_eks_cluster_id" {
  description = "EKS Cluster Security Group ID (for future use)"
  value       = aws_security_group.eks_cluster.id
}

# -----------------------------------------------------------------------------
# SSH Key Outputs
# -----------------------------------------------------------------------------
output "ssh_key_name" {
  description = "SSH Key Pair Name"
  value       = aws_key_pair.generated.key_name
}

output "ssh_private_key_path" {
  description = "SSH Private Key File Path"
  value       = local_file.private_key.filename
}

# -----------------------------------------------------------------------------
# Connection Commands
# -----------------------------------------------------------------------------
output "ssh_bastion_command" {
  description = "SSH command to connect to Bastion Host"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_mgmt_via_bastion_command" {
  description = "SSH command to connect to Management Server via Bastion (ProxyJump)"
  value       = "ssh -i ${var.key_name}.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.mgmt.private_ip}"
}

output "mysql_connect_command" {
  description = "MySQL connection command (run from Management Server)"
  value       = "mysql -h ${aws_db_instance.main.address} -P ${aws_db_instance.main.port} -u <USERNAME> -p"
}

# -----------------------------------------------------------------------------
# EKS Configuration (for eksctl)
# -----------------------------------------------------------------------------
output "eks_cluster_config" {
  description = "EKS cluster configuration for eksctl"
  value       = <<-EOT
    # eksctl 클러스터 생성 명령어 (Management Server에서 실행)
    eksctl create cluster \
      --name ${var.eks_cluster_name} \
      --region ${var.aws_region} \
      --vpc-private-subnets ${join(",", aws_subnet.private_app[*].id)} \
      --vpc-public-subnets ${join(",", aws_subnet.public[*].id)} \
      --without-nodegroup
    
    # 관리형 노드 그룹 추가
    eksctl create nodegroup \
      --cluster ${var.eks_cluster_name} \
      --region ${var.aws_region} \
      --name ${var.eks_cluster_name}-ng \
      --node-type t3.medium \
      --nodes 2 \
      --nodes-min 1 \
      --nodes-max 4 \
      --node-private-networking
  EOT
}

# -----------------------------------------------------------------------------
# S3 Backend Outputs
# -----------------------------------------------------------------------------
output "tfstate_bucket_name" {
  description = "Terraform state S3 버킷 이름"
  value       = var.tfstate_bucket_name != "" ? aws_s3_bucket.terraform_state[0].id : "Not configured"
}

output "tfstate_bucket_arn" {
  description = "Terraform state S3 버킷 ARN"
  value       = var.tfstate_bucket_name != "" ? aws_s3_bucket.terraform_state[0].arn : "Not configured"
}

output "s3_object_lock_enabled" {
  description = "S3 Object Lock 활성화 여부"
  value       = var.tfstate_bucket_name != "" && var.enable_s3_object_lock ? "Enabled (${var.s3_object_lock_mode} mode, ${var.s3_object_lock_days} days)" : "Disabled"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
output "infrastructure_summary" {
  description = "Infrastructure deployment summary"
  value       = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                    PetClinic Infrastructure Summary                   ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║  VPC:                ${aws_vpc.main.id}
    ║  Region:             ${var.aws_region}
    ║  Environment:        ${var.environment}
    ╠══════════════════════════════════════════════════════════════════════╣
    ║  Bastion IP:         ${aws_instance.bastion.public_ip}
    ║  Mgmt Server IP:     ${aws_instance.mgmt.private_ip} (Private)
    ╠══════════════════════════════════════════════════════════════════════╣
    ║  RDS Endpoint:       ${aws_db_instance.main.endpoint}
    ║  RDS Database:       ${aws_db_instance.main.db_name}
    ╠══════════════════════════════════════════════════════════════════════╣
    ║  NAT Gateway:        2개 (HA - Zonal Isolation)
    ║  EKS Cluster Name:   ${var.eks_cluster_name} (추후 생성 예정)
    ╠══════════════════════════════════════════════════════════════════════╣
    ║  Terraform State:    ${var.tfstate_bucket_name != "" ? aws_s3_bucket.terraform_state[0].id : "로컬 저장"}
    ║  Object Lock:        ${var.tfstate_bucket_name != "" && var.enable_s3_object_lock ? "활성화 (${var.s3_object_lock_mode}, ${var.s3_object_lock_days}일)" : "비활성화"}
    ╚══════════════════════════════════════════════════════════════════════╝
    
    🔐 SSH 접속 방법:
    1. Bastion 접속:
       ssh -i ${var.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}
    
    2. Management Server 접속 (ProxyJump):
       ssh -i ${var.key_name}.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.mgmt.private_ip}
    
    📂 DB 초기화:
       Management Server에서 /home/ubuntu/init.sql 파일을 사용하여 초기화
       ./db-connect.sh 스크립트 사용 또는
       mysql -h ${aws_db_instance.main.address} -u <USERNAME> -p < /home/ubuntu/init.sql
    
  EOT
}

