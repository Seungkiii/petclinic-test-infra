# =============================================================================
# S3 Backend for Terraform State
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Bucket for Terraform State
# Object Lock 활성화, 버전 관리, 암호화 포함
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  # 버킷 이름이 제공되지 않으면 생성하지 않음
  count  = var.tfstate_bucket_name != "" ? 1 : 0
  bucket = var.tfstate_bucket_name

  # 실수로 삭제되는 것을 방지
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Purpose     = "Terraform State Storage"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket Versioning
# State 파일의 버전 관리 (롤백 및 복구 가능)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.tfstate_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket Object Lock Configuration
# State 파일 보호 및 동시성 제어
# 주의: 버킷 생성 시에만 활성화 가능 (생성 후 비활성화 불가)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_object_lock_configuration" "terraform_state" {
  count  = var.tfstate_bucket_name != "" && var.enable_s3_object_lock ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    default_retention {
      mode = var.s3_object_lock_mode
      days = var.s3_object_lock_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

# -----------------------------------------------------------------------------
# S3 Bucket Encryption
# State 파일 암호화 (기본 암호화 사용)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.tfstate_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket Public Access Block
# State 파일은 공개 접근 불가
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.tfstate_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# S3 Bucket Lifecycle Configuration
# 오래된 버전 정리 (선택적)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count  = var.tfstate_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    id     = "delete-old-noncurrent-versions"
    status = "Enabled"

    # 모든 객체에 적용 (빈 filter)
    filter {}

    # Object Lock이 활성화된 경우, 보관 기간 동안은 삭제되지 않음
    noncurrent_version_expiration {
      noncurrent_days = 90 # 90일 후 비현재 버전 삭제
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

# -----------------------------------------------------------------------------
# S3 Bucket Policy
# Terraform이 state 파일에 접근할 수 있도록 권한 부여
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_state" {
  count = var.tfstate_bucket_name != "" ? 1 : 0

  # 현재 계정의 모든 사용자가 읽기/쓰기 가능
  # 프로덕션에서는 특정 IAM 역할/사용자로 제한 권장
  statement {
    sid    = "AllowTerraformStateAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetObjectVersion",
      "s3:DeleteObjectVersion",
      "s3:GetObjectAttributes",
      "s3:PutObjectAcl",
    ]

    resources = [
      aws_s3_bucket.terraform_state[0].arn,
      "${aws_s3_bucket.terraform_state[0].arn}/*",
    ]
  }

  # Object Lock 관련 권한
  statement {
    sid    = "AllowObjectLockOperations"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "s3:BypassGovernanceRetention",
      "s3:GetObjectRetention",
      "s3:PutObjectRetention",
      "s3:GetObjectLegalHold",
      "s3:PutObjectLegalHold",
    ]

    resources = [
      "${aws_s3_bucket.terraform_state[0].arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  count  = var.tfstate_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  policy = data.aws_iam_policy_document.terraform_state[0].json

  depends_on = [
    aws_s3_bucket_public_access_block.terraform_state,
    aws_s3_bucket_object_lock_configuration.terraform_state,
  ]
}

