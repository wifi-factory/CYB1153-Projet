#!/bin/bash
set -euxo pipefail

yum update -y
yum install -y httpd php php-cli php-mysqlnd
yum install -y mariadb105 || yum install -y mariadb

mkdir -p /var/www/html

cat <<'PHP' > /var/www/html/SamplePage.php
${sample_page_php}
PHP

cat <<'PHP' > /var/www/html/db_config.php
${db_config_php}
PHP

cat <<'PHP' > /var/www/html/db_settings.local.php
<?php
declare(strict_types=1);

return json_decode(<<<'JSON'
${db_settings_json}
JSON
, true, 512, JSON_THROW_ON_ERROR);
PHP

cat <<'HTML' > /var/www/html/index.html
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
HTML

chown apache:apache /var/www/html/SamplePage.php /var/www/html/db_config.php /var/www/html/db_settings.local.php /var/www/html/index.html
chmod 640 /var/www/html/db_settings.local.php
restorecon -Rv /var/www/html >/dev/null 2>&1 || true

systemctl enable httpd
systemctl restart httpd
