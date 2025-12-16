# =============================================================================
# IAM Roles and Policies
# Management Server를 위한 IAM 설정
# =============================================================================

# -----------------------------------------------------------------------------
# Management Server IAM Role
# eksctl, kubectl 등 AWS 서비스 관리를 위한 역할
# -----------------------------------------------------------------------------
resource "aws_iam_role" "mgmt_server" {
  name = "${var.project_name}-mgmt-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mgmt-server-role"
  }
}

# -----------------------------------------------------------------------------
# AdministratorAccess Policy 연결
# EKS 클러스터 생성 및 관리를 위해 필요
# 프로덕션에서는 최소 권한 원칙에 따라 세분화된 정책 사용 권장
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "mgmt_admin" {
  role       = aws_iam_role.mgmt_server.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# IAM Instance Profile
# EC2 인스턴스에 IAM Role 연결을 위한 프로파일
# -----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "mgmt_server" {
  name = "${var.project_name}-mgmt-server-profile"
  role = aws_iam_role.mgmt_server.name

  tags = {
    Name = "${var.project_name}-mgmt-server-profile"
  }
}

