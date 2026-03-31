#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_APP_SOURCE="${REPO_ROOT}/app"

APP_SOURCE_DIR="${1:-${DEFAULT_APP_SOURCE}}"
WEB_ROOT="${2:-/var/www/html}"

if [[ ! -d "${APP_SOURCE_DIR}" ]]; then
  echo "Application source directory not found: ${APP_SOURCE_DIR}" >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

${SUDO} yum install -y httpd php php-cli php-mysqlnd
${SUDO} yum install -y mariadb105 || ${SUDO} yum install -y mariadb

${SUDO} mkdir -p "${WEB_ROOT}"
${SUDO} cp "${APP_SOURCE_DIR}/SamplePage.php" "${WEB_ROOT}/SamplePage.php"
${SUDO} cp "${APP_SOURCE_DIR}/db_config.php" "${WEB_ROOT}/db_config.php"

if [[ -n "${APP_DB_HOST:-}" && -n "${APP_DB_PASSWORD:-}" ]]; then
  TEMP_CONFIG="$(mktemp)"
  DB_SETTINGS_JSON="$(
    APP_DB_HOST="${APP_DB_HOST}" \
    APP_DB_PORT="${APP_DB_PORT:-3306}" \
    APP_DB_NAME="${APP_DB_NAME:-sample}" \
    APP_DB_USER="${APP_DB_USER:-tutorial_user}" \
    APP_DB_PASSWORD="${APP_DB_PASSWORD}" \
    php -r 'echo json_encode([
        "host" => getenv("APP_DB_HOST"),
        "port" => (int) getenv("APP_DB_PORT"),
        "name" => getenv("APP_DB_NAME"),
        "user" => getenv("APP_DB_USER"),
        "password" => getenv("APP_DB_PASSWORD"),
        "charset" => "utf8mb4",
    ], JSON_THROW_ON_ERROR);'
  )"
  cat > "${TEMP_CONFIG}" <<EOF
<?php
declare(strict_types=1);

return json_decode(<<<'JSON'
${DB_SETTINGS_JSON}
JSON
, true, 512, JSON_THROW_ON_ERROR);
EOF
  ${SUDO} cp "${TEMP_CONFIG}" "${WEB_ROOT}/db_settings.local.php"
  rm -f "${TEMP_CONFIG}"
  ${SUDO} chmod 640 "${WEB_ROOT}/db_settings.local.php"
fi

TEMP_INDEX="$(mktemp)"
cat > "${TEMP_INDEX}" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="0; url=/SamplePage.php">
  <title>CYB1153 App</title>
</head>
<body>
  <p>Redirecting to <a href="/SamplePage.php">SamplePage.php</a>...</p>
</body>
</html>
EOF
${SUDO} cp "${TEMP_INDEX}" "${WEB_ROOT}/index.html"
rm -f "${TEMP_INDEX}"

${SUDO} chown apache:apache "${WEB_ROOT}/SamplePage.php" "${WEB_ROOT}/db_config.php" "${WEB_ROOT}/index.html"
if [[ -f "${WEB_ROOT}/db_settings.local.php" ]]; then
  ${SUDO} chown apache:apache "${WEB_ROOT}/db_settings.local.php"
fi

${SUDO} restorecon -Rv "${WEB_ROOT}" >/dev/null 2>&1 || true
${SUDO} systemctl enable httpd
${SUDO} systemctl restart httpd

echo "Application deployed to ${WEB_ROOT}"
