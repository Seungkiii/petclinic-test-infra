# =============================================================================
# Security Groups
# 용도별 보안 그룹 정의
# =============================================================================

# -----------------------------------------------------------------------------
# Bastion Host Security Group
# SSH(22) 포트만 허용 - 특정 IP에서만 접근 가능
# -----------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "Security group for Bastion Host - SSH access from allowed IPs"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-bastion"
  }
}

# -----------------------------------------------------------------------------
# Management Server Security Group
# SSH(22) - Bastion Host로부터만 접근 가능
# -----------------------------------------------------------------------------
resource "aws_security_group" "mgmt" {
  name        = "${var.project_name}-sg-mgmt"
  description = "Security group for Management Server - SSH from Bastion only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-mgmt"
  }
}

# -----------------------------------------------------------------------------
# RDS Security Group
# MySQL(3306) - Management Server SG 및 Private Subnet CIDR에서 접근 가능
# (추후 EKS 파드에서 접근할 수 있도록 Private Subnet CIDR 허용)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "Security group for RDS - MySQL access from Mgmt and Private subnets"
  vpc_id      = aws_vpc.main.id

  # Management Server에서 접근 허용
  ingress {
    description     = "MySQL from Management Server"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.mgmt.id]
  }

  # App Private Subnet CIDR에서 접근 허용 (EKS 파드용)
  dynamic "ingress" {
    for_each = var.app_private_subnet_cidrs
    content {
      description = "MySQL from App Private Subnet ${ingress.key + 1}"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-rds"
  }
}

# -----------------------------------------------------------------------------
# EKS Cluster Security Group (참조용 - 추후 eksctl에서 사용)
# 클러스터와 노드 간 통신을 위한 기본 규칙
# -----------------------------------------------------------------------------
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-sg-eks-cluster"
  description = "Security group for EKS Cluster (created for future use)"
  vpc_id      = aws_vpc.main.id

  # 클러스터 내부 통신
  ingress {
    description = "Allow internal cluster communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # HTTPS from VPC (kubectl 접근)
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-eks-cluster"
  }
}

