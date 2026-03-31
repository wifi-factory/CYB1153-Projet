<?php
declare(strict_types=1);

require_once __DIR__ . '/db_config.php';

$config = get_database_config();
$missingConfig = database_config_placeholders($config);
$connectionStatus = 'Configuration DB incomplete';
$connectionError = null;
$formError = null;
$formSuccess = null;
$employees = [];

if (database_config_ready($config)) {
    try {
        $pdo = create_database_connection($config);
        $connectionStatus = 'Connexion BD : OK';

        $pdo->exec(
            'CREATE TABLE IF NOT EXISTS Employees (
                EmployeeID INT AUTO_INCREMENT PRIMARY KEY,
                Name VARCHAR(150) NOT NULL,
                Address VARCHAR(255) NOT NULL,
                CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
        );

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $name = trim((string) ($_POST['name'] ?? ''));
            $address = trim((string) ($_POST['address'] ?? ''));

            if ($name === '' || $address === '') {
                $formError = 'Name and Address are required.';
            } elseif (strlen($name) > 150 || strlen($address) > 255) {
                $formError = 'One of the fields is too long for the database schema.';
            } else {
                $insertStatement = $pdo->prepare(
                    'INSERT INTO Employees (Name, Address) VALUES (:name, :address)'
                );
                $insertStatement->execute([
                    ':name' => $name,
                    ':address' => $address,
                ]);
                $formSuccess = 'Employee added successfully.';
            }
        }

        $employees = $pdo
            ->query('SELECT EmployeeID, Name, Address, CreatedAt FROM Employees ORDER BY EmployeeID DESC')
            ->fetchAll();
    } catch (Throwable $exception) {
        $connectionStatus = 'Connexion BD : ERROR';
        $connectionError = $exception->getMessage();
    }
}

function h(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CYB1153 Employee Directory</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f7fb;
      --panel: #ffffff;
      --text: #18212b;
      --muted: #5b6b7c;
      --primary: #0b5cab;
      --primary-soft: #dceafb;
      --ok: #1f7a45;
      --warn: #965f00;
      --danger: #a52a2a;
      --border: #d8e1eb;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(180deg, #edf3fb 0%, #f9fbfd 100%);
      color: var(--text);
    }

    .container {
      max-width: 1080px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }

    .hero,
    .panel {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 18px;
      box-shadow: 0 10px 30px rgba(14, 32, 56, 0.08);
    }

    .hero {
      padding: 28px;
      margin-bottom: 24px;
    }

    .eyebrow {
      display: inline-block;
      margin-bottom: 12px;
      padding: 6px 10px;
      border-radius: 999px;
      background: var(--primary-soft);
      color: var(--primary);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    h1 {
      margin: 0 0 10px;
      font-size: 32px;
    }

    .hero p {
      margin: 0;
      color: var(--muted);
      line-height: 1.6;
    }

    .status-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 16px;
      margin-top: 24px;
    }

    .status-card {
      padding: 18px;
      border-radius: 14px;
      border: 1px solid var(--border);
      background: #fbfdff;
    }

    .status-card strong {
      display: block;
      margin-bottom: 6px;
      font-size: 13px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }

    .status-ok {
      color: var(--ok);
    }

    .status-warn {
      color: var(--warn);
    }

    .status-danger {
      color: var(--danger);
    }

    .layout {
      display: grid;
      grid-template-columns: 1fr 1.2fr;
      gap: 24px;
    }

    .panel {
      padding: 24px;
    }

    h2 {
      margin-top: 0;
      margin-bottom: 16px;
      font-size: 22px;
    }

    label {
      display: block;
      margin-bottom: 8px;
      font-weight: 600;
    }

    input[type="text"] {
      width: 100%;
      padding: 12px 14px;
      margin-bottom: 14px;
      border: 1px solid var(--border);
      border-radius: 10px;
      font-size: 15px;
    }

    button {
      border: 0;
      border-radius: 10px;
      padding: 12px 18px;
      background: var(--primary);
      color: #ffffff;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
    }

    button:disabled {
      background: #9ab3cf;
      cursor: not-allowed;
    }

    .message {
      margin-bottom: 16px;
      padding: 12px 14px;
      border-radius: 10px;
      font-size: 14px;
    }

    .message.error {
      background: #fff1f1;
      color: var(--danger);
    }

    .message.success {
      background: #edf9f1;
      color: var(--ok);
    }

    .message.warn {
      background: #fff7e6;
      color: var(--warn);
    }

    table {
      width: 100%;
      border-collapse: collapse;
    }

    th,
    td {
      text-align: left;
      padding: 12px 10px;
      border-bottom: 1px solid var(--border);
      vertical-align: top;
    }

    th {
      font-size: 13px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    code {
      padding: 2px 6px;
      border-radius: 6px;
      background: #eef4fb;
      font-size: 13px;
    }

    ul {
      margin-top: 10px;
      padding-left: 18px;
      color: var(--muted);
    }

    @media (max-width: 860px) {
      .layout {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <section class="hero">
      <span class="eyebrow">CYB1153 | AWS | PHP</span>
      <h1>Employee Directory</h1>
      <p>This page demonstrates the dynamic part of the CYB1153 AWS project. It connects to MySQL, creates the <code>Employees</code> table if needed, inserts new rows and lists existing records.</p>

      <div class="status-grid">
        <div class="status-card">
          <strong>Database Status</strong>
          <span class="<?= $connectionStatus === 'Connexion BD : OK' ? 'status-ok' : ($connectionError ? 'status-danger' : 'status-warn') ?>">
            <?= h($connectionStatus) ?>
          </span>
        </div>
        <div class="status-card">
          <strong>Database Host</strong>
          <span><?= h((string) $config['host']) ?></span>
        </div>
        <div class="status-card">
          <strong>Database Name</strong>
          <span><?= h((string) $config['name']) ?></span>
        </div>
      </div>
    </section>

    <div class="layout">
      <section class="panel">
        <h2>Add an Employee</h2>

        <?php if ($formError !== null): ?>
          <div class="message error"><?= h($formError) ?></div>
        <?php endif; ?>

        <?php if ($formSuccess !== null): ?>
          <div class="message success"><?= h($formSuccess) ?></div>
        <?php endif; ?>

        <?php if (!empty($missingConfig)): ?>
          <div class="message warn">
            Database access is not fully configured yet. Provide a local <code>db_settings.local.php</code> file or define the environment variables <code>APP_DB_HOST</code>, <code>APP_DB_PASSWORD</code>, <code>APP_DB_NAME</code>, <code>APP_DB_USER</code> and <code>APP_DB_PORT</code>.
          </div>
        <?php endif; ?>

        <?php if ($connectionError !== null): ?>
          <div class="message error">MySQL connection failed: <?= h($connectionError) ?></div>
        <?php endif; ?>

        <form method="post" action="">
          <label for="name">Name</label>
          <input id="name" name="name" type="text" maxlength="150" placeholder="Jane Doe" required>

          <label for="address">Address</label>
          <input id="address" name="address" type="text" maxlength="255" placeholder="123 Example Street" required>

          <button type="submit" <?= database_config_ready($config) && $connectionError === null ? '' : 'disabled' ?>>Save to MySQL</button>
        </form>
      </section>

      <section class="panel">
        <h2>Stored Employees</h2>

        <?php if (!database_config_ready($config) || $connectionError !== null): ?>
          <p>No database records can be shown until the MySQL configuration is complete and reachable.</p>
          <ul>
            <li>Fill the placeholders in Terraform before deployment.</li>
            <li>Redeploy the web instances or update <code>db_settings.local.php</code>.</li>
            <li>Verify that the EC2 security group can reach RDS on port 3306.</li>
          </ul>
        <?php elseif ($employees === []): ?>
          <p>The table exists but no employees have been inserted yet.</p>
        <?php else: ?>
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Address</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              <?php foreach ($employees as $employee): ?>
                <tr>
                  <td><?= h((string) $employee['EmployeeID']) ?></td>
                  <td><?= h((string) $employee['Name']) ?></td>
                  <td><?= h((string) $employee['Address']) ?></td>
                  <td><?= h((string) $employee['CreatedAt']) ?></td>
                </tr>
              <?php endforeach; ?>
            </tbody>
          </table>
        <?php endif; ?>
      </section>
    </div>
  </div>
</body>
</html>
