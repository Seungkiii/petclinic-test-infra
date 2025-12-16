#!/bin/bash
# =============================================================================
# S3 버킷을 제외하고 Terraform 리소스 삭제 스크립트
# State 파일은 유지하면서 인프라만 삭제
# =============================================================================

set -e

echo "=========================================="
echo "S3 버킷을 제외하고 Terraform Destroy 실행"
echo "=========================================="
echo ""

# S3 관련 리소스 목록
S3_RESOURCES=(
    "aws_s3_bucket.terraform_state[0]"
    "aws_s3_bucket_versioning.terraform_state[0]"
    "aws_s3_bucket_object_lock_configuration.terraform_state[0]"
    "aws_s3_bucket_server_side_encryption_configuration.terraform_state[0]"
    "aws_s3_bucket_public_access_block.terraform_state[0]"
    "aws_s3_bucket_policy.terraform_state[0]"
    "aws_s3_bucket_lifecycle_configuration.terraform_state[0]"
)

# 모든 리소스 목록 가져오기
echo "[1/3] 리소스 목록 확인 중..."
ALL_RESOURCES=$(terraform state list 2>/dev/null || echo "")

if [ -z "$ALL_RESOURCES" ]; then
    echo "❌ State 파일이 없거나 초기화되지 않았습니다."
    exit 1
fi

# S3 리소스를 제외한 리소스 목록 생성
echo "[2/3] S3 리소스를 제외한 리소스 목록 생성 중..."
TARGETS=""
for resource in $ALL_RESOURCES; do
    is_s3_resource=false
    for s3_resource in "${S3_RESOURCES[@]}"; do
        if [ "$resource" == "$s3_resource" ]; then
            is_s3_resource=true
            break
        fi
    done
    
    if [ "$is_s3_resource" == false ]; then
        if [ -z "$TARGETS" ]; then
            TARGETS="-target=$resource"
        else
            TARGETS="$TARGETS -target=$resource"
        fi
    fi
done

if [ -z "$TARGETS" ]; then
    echo "⚠️  삭제할 리소스가 없습니다 (S3 버킷만 존재)."
    exit 0
fi

echo "[3/3] Destroy 실행 중..."
echo ""
echo "다음 리소스들이 삭제됩니다:"
terraform state list | grep -v "aws_s3_bucket"
echo ""
read -p "계속하시겠습니까? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "취소되었습니다."
    exit 0
fi

# Destroy 실행
terraform destroy $TARGETS

echo ""
echo "=========================================="
echo "✅ Destroy 완료!"
echo "S3 버킷은 유지되었습니다."
echo "=========================================="

