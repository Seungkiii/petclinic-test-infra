#!/bin/bash
# =============================================================================
# S3 버킷 완전 정리 스크립트
# Object Lock이 활성화된 버킷의 모든 버전 삭제
# =============================================================================

set -e

BUCKET_NAME="petclinic-terraform-state-prod-ap-northeast-2"

echo "=========================================="
echo "S3 버킷 정리 시작: $BUCKET_NAME"
echo "=========================================="

# 1. 모든 객체 버전 가져오기
echo "[1/3] 모든 객체 버전 조회 중..."
VERSIONS=$(aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --query 'Versions[*].[Key,VersionId]' \
  --output text)

DELETE_MARKERS=$(aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --query 'DeleteMarkers[*].[Key,VersionId]' \
  --output text)

# 2. 모든 버전 삭제 (Object Lock 해제)
if [ ! -z "$VERSIONS" ]; then
  echo "[2/3] 모든 객체 버전 삭제 중 (Object Lock 해제)..."
  echo "$VERSIONS" | while read -r key version_id; do
    if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
      echo "  삭제 중: $key (Version: $version_id)"
      aws s3api delete-object \
        --bucket "$BUCKET_NAME" \
        --key "$key" \
        --version-id "$version_id" \
        --bypass-governance-retention 2>/dev/null || \
      aws s3api delete-object \
        --bucket "$BUCKET_NAME" \
        --key "$key" \
        --version-id "$version_id"
    fi
  done
fi

# 3. Delete Markers 삭제
if [ ! -z "$DELETE_MARKERS" ]; then
  echo "[3/3] Delete Markers 삭제 중..."
  echo "$DELETE_MARKERS" | while read -r key version_id; do
    if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
      echo "  Delete Marker 삭제 중: $key (Version: $version_id)"
      aws s3api delete-object \
        --bucket "$BUCKET_NAME" \
        --key "$key" \
        --version-id "$version_id" \
        --bypass-governance-retention 2>/dev/null || \
      aws s3api delete-object \
        --bucket "$BUCKET_NAME" \
        --key "$key" \
        --version-id "$version_id"
    fi
  done
fi

# 4. 버킷 삭제
echo ""
echo "[4/4] 버킷 삭제 중..."
aws s3 rb s3://"$BUCKET_NAME" --force 2>&1 || {
  echo "버킷이 비어있지 않거나 삭제 권한이 없습니다."
  echo "수동으로 확인하세요: aws s3 ls s3://$BUCKET_NAME"
  exit 1
}

echo ""
echo "=========================================="
echo "✅ S3 버킷 정리 완료!"
echo "=========================================="

