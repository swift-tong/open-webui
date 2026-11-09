#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# 构建 Open WebUI 自建镜像（linux/amd64）并推送 ACR
#
# 用法（在本机 Mac / 任意构建机执行）：
#   ./deploy/build.sh                          # tag 自动用日期
#   ./deploy/build.sh scm-custom-20261110      # 指定 tag
#   ./deploy/build.sh latest --no-push         # 只构建不推送
#
# 环境变量：
#   REGISTRY       镜像仓库地址（默认 registry.cn-shanghai.aliyuncs.com/daxia-hermer）
#   IMAGE_NAME     仓库内镜像名（默认 open-webui）
#   PLATFORM       目标平台（默认 linux/amd64；部署机是 x86_64，不要改成 arm64）
#   ACR_USERNAME / ACR_PASSWORD   推送前的仓库账号（不填则复用已有 docker login 状态）
# ══════════════════════════════════════════════════════════════
set -euo pipefail

REGISTRY="${REGISTRY:-registry.cn-shanghai.aliyuncs.com/daxia-hermer}"
IMAGE_NAME="${IMAGE_NAME:-open-webui}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG=""
PUSH=1

for arg in "$@"; do
  case "$arg" in
    --no-push) PUSH=0 ;;
    -*) echo "未知参数: $arg" >&2; exit 1 ;;
    *) TAG="$arg" ;;
  esac
done

TAG="${TAG:-scm-custom-$(date +%Y%m%d)}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_TAG="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "==> 构建目录: $ROOT"
echo "==> 目标镜像: $REMOTE_TAG"
echo "==> 目标平台: $PLATFORM"

docker build --platform "$PLATFORM" -t "$REMOTE_TAG" "$ROOT"

if [ "$PUSH" = "1" ]; then
  if [ -n "${ACR_PASSWORD:-}" ]; then
    echo "==> 登录 ${REGISTRY}"
    echo "$ACR_PASSWORD" | docker login "$REGISTRY" -u "${ACR_USERNAME:?需要 ACR_USERNAME}" --password-stdin
  fi
  echo "==> 推送 $REMOTE_TAG"
  docker push "$REMOTE_TAG"
  echo "==> 完成"
  echo "    镜像: $REMOTE_TAG"
  echo "    部署机拉取前记得 docker login $REGISTRY"
else
  echo "==> 已跳过推送（--no-push）"
fi
