# =============================================================================
# EC2 Instances
# Bastion Host 및 Management Server
# =============================================================================

# -----------------------------------------------------------------------------
# Data Source: Latest Ubuntu 22.04 LTS AMI
# -----------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# -----------------------------------------------------------------------------
# TLS Private Key for SSH (선택적 - 기존 키 사용 시 제외)
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "${var.project_name}-keypair"
  }
}

# 프라이빗 키를 로컬에 저장 (terraform apply 후 확인)
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/mykey/${var.key_name}.pem"
  file_permission = "0400"
}

# -----------------------------------------------------------------------------
# Bastion Host
# 위치: Public Subnet A
# Public IP 할당됨
# -----------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = var.ec2_ami_id != null ? var.ec2_ami_id : data.aws_ami.ubuntu.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public[0].id # Public Subnet A
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.generated.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-bastion"
    Role = "Bastion"
  }

  # 간단한 초기화 스크립트
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # 시스템 업데이트
    apt-get update -y
    apt-get upgrade -y
    
    # 기본 도구 설치
    apt-get install -y vim htop curl wget unzip
    
    echo "Bastion host initialization completed!" >> /var/log/user-data.log
  EOF
}

# -----------------------------------------------------------------------------
# Management Server
# 위치: App Private Subnet A (보안을 위해 Private에 배치)
# Bastion을 통해서만 SSH 접근 가능
# -----------------------------------------------------------------------------
resource "aws_instance" "mgmt" {
  ami                    = var.ec2_ami_id != null ? var.ec2_ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.mgmt_instance_type
  subnet_id              = aws_subnet.private_app[0].id # App Private Subnet A
  vpc_security_group_ids = [aws_security_group.mgmt.id]
  key_name               = aws_key_pair.generated.key_name
  iam_instance_profile   = aws_iam_instance_profile.mgmt_server.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50 # 도커 이미지 등을 위한 충분한 공간
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 2          # Docker 컨테이너에서 접근 가능하도록
  }

  tags = {
    Name = "${var.project_name}-mgmt-server"
    Role = "Management"
  }

  # User Data 스크립트 (외부 파일 사용)
  user_data = templatefile("${path.module}/user_data_mgmt.sh", {
    aws_region       = var.aws_region
    eks_cluster_name = var.eks_cluster_name
    db_endpoint      = "" # RDS 생성 후 업데이트됨
    db_username      = var.db_username
    db_password      = var.db_password
  })

  # RDS가 먼저 생성되어야 함
  depends_on = [aws_nat_gateway.main]
}

