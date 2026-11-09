#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Open WebUI 一键部署（在部署机执行，需 root）
#
#   cd deploy && cp .env.example .env && vi .env     # 填密钥与地址
#   ./deploy.sh
#
# 做的事：装 nginx → 登录拉镜像 → 起容器 → 装 nginx 反代 →（可选）申请 HTTPS
# ══════════════════════════════════════════════════════════════
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DEPLOY_DIR"

[ -f .env ] || { echo "缺少 .env：先执行 cp .env.example .env && vi .env" >&2; exit 1; }
set -a; . ./.env; set +a

: "${OPEN_WEBUI_IMAGE:?需要 OPEN_WEBUI_IMAGE}"
: "${HERMES_API_BASE_URL:?需要 HERMES_API_BASE_URL}"
: "${DOMAIN:?需要 DOMAIN}"

DATA_DIR="${OPEN_WEBUI_DATA_DIR:-/var/deploy/open-webui/data}"
NGINX_CONF="/etc/nginx/conf.d/${DOMAIN}.conf"

# ── 1) 安装 nginx ─────────────────────────────────────────────
if ! command -v nginx >/dev/null 2>&1; then
  echo "==> 安装 nginx"
  apt-get update -qq
  apt-get install -y -qq nginx
fi

# ── 2) 登录镜像仓库并拉取 ──────────────────────────────────────
if [ -n "${ACR_PASSWORD:-}" ]; then
  echo "==> 登录 ${ACR_REGISTRY}"
  echo "$ACR_PASSWORD" | docker login "$ACR_REGISTRY" -u "${ACR_USERNAME:?需要 ACR_USERNAME}" --password-stdin
fi

echo "==> 准备数据目录 $DATA_DIR"
mkdir -p "$DATA_DIR"

echo "==> 拉取并启动容器"
docker compose --env-file .env pull
docker compose --env-file .env up -d

# ── 3) nginx 反向代理 ────────────────────────────────────────
echo "==> 安装 nginx 配置 $NGINX_CONF"
install -m 644 "nginx/${DOMAIN}.conf" "$NGINX_CONF"
nginx -t
systemctl reload nginx

# ── 4) 可选：Let's Encrypt 证书 ───────────────────────────────
if [ -n "${LETSENCRYPT_EMAIL:-}" ] && [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
  echo "==> 申请 HTTPS 证书"
  apt-get install -y -qq certbot python3-certbot-nginx
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
    -m "$LETSENCRYPT_EMAIL" --redirect || echo "!! 证书申请失败（检查域名解析是否指向本机）"
fi

echo "==> 完成"
echo "    本地: http://127.0.0.1:${OPEN_WEBUI_PORT:-8690}"
echo "    域名: http://${DOMAIN}$([ -d "/etc/letsencrypt/live/${DOMAIN}" ] && echo " / https://${DOMAIN}")"
echo "    首次访问注册的账号自动成为管理员"
