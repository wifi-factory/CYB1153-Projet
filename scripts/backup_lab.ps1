[CmdletBinding()]
param(
    [string]$Region = "us-east-1",
    [string]$BackupRoot = "backups",
    [string]$AlbName = "ALB-annuaire",
    [string]$TargetGroupName = "Group-web",
    [string]$DbInstanceIdentifier = "tutorial-db-instance",
    [string]$BucketName = "cyb1153-annuaire-2026",
    [string]$DashboardName = "CYB1153-Dashboard",
    [string[]]$Ec2Names = @("Web-1", "Web-2"),
    [switch]$DownloadS3,
    [switch]$CreateRdsSnapshot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$backupBase = if ([System.IO.Path]::IsPathRooted($BackupRoot)) {
    $BackupRoot
} else {
    Join-Path $repoRoot $BackupRoot
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $backupBase $timestamp
$null = New-Item -ItemType Directory -Path $backupDir -Force

function Find-CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [string[]]$CandidatePaths = @()
    )

    foreach ($candidate in $CandidatePaths) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    throw "Commande introuvable: $CommandName"
}

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $script:awsCli @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { "$_" }) -join [Environment]::NewLine

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "aws $($Arguments -join ' ') a echoue.`n$text"
    }

    [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = $text
    }
}

function Export-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $result = Invoke-AwsCli -Arguments $Arguments -AllowFailure:$AllowFailure
    $path = Join-Path $script:backupDir $FileName
    $result.Output | Set-Content -LiteralPath $path -Encoding utf8

    if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Output)) {
        return $null
    }

    try {
        return $result.Output | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Write-Summary {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Data
    )

    $lines = @(
        "Backup AWS - $($Data.Timestamp)",
        "Compte: $($Data.Account)",
        "ARN: $($Data.Arn)",
        "Region: $($Data.Region)",
        "Commit Git: $($Data.GitCommit)",
        "",
        "Ressources ciblees:",
        "- ALB: $($Data.AlbName)",
        "- Target Group: $($Data.TargetGroupName)",
        "- RDS: $($Data.DbInstanceIdentifier)",
        "- Bucket S3: $($Data.BucketName)",
        "- Dashboard CloudWatch: $($Data.DashboardName)",
        "- Instances EC2: $($Data.Ec2Names -join ', ')",
        "",
        "Ce backup exporte la configuration AWS en JSON pour pouvoir comparer ou reconstruire l'architecture sans cout de stockage important.",
        "Options couteuses non activees par defaut:",
        "- CreateRdsSnapshot: cree un snapshot manuel RDS",
        "- DownloadS3: telecharge localement le contenu du bucket S3"
    )

    $summaryPath = Join-Path $script:backupDir "summary.txt"
    $lines | Set-Content -LiteralPath $summaryPath -Encoding utf8
}

$awsCli = Find-CommandPath -CommandName "aws" -CandidatePaths @(
    "C:\Program Files\Amazon\AWSCLIV2\aws.exe",
    "C:\Program Files\Amazon\AWSCLI\bin\aws.exe"
)

$gitCli = Find-CommandPath -CommandName "git"

$callerIdentity = Export-AwsJson -FileName "sts-get-caller-identity.json" -Arguments @(
    "sts", "get-caller-identity", "--output", "json"
)

if ($null -eq $callerIdentity) {
    throw "Impossible de verifier l'identite AWS. Configure d'abord AWS CLI."
}

$gitCommit = (& $gitCli -C $repoRoot rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0) {
    $gitCommit = "inconnu"
}

$describeInstances = Export-AwsJson -FileName "ec2-describe-instances.json" -Arguments @(
    "ec2", "describe-instances",
    "--filters",
    "Name=tag:Name,Values=$($Ec2Names -join ',')",
    "Name=instance-state-name,Values=running,stopped,pending,stopping",
    "--region", $Region,
    "--output", "json"
)

$describeSecurityGroups = Export-AwsJson -FileName "ec2-describe-security-groups.json" -Arguments @(
    "ec2", "describe-security-groups",
    "--filters",
    "Name=group-name,Values=LB-SG,Web-SG,DB-SG",
    "--region", $Region,
    "--output", "json"
)

$describeVpcs = Export-AwsJson -FileName "ec2-describe-vpcs.json" -Arguments @(
    "ec2", "describe-vpcs",
    "--region", $Region,
    "--output", "json"
)

$describeSubnets = Export-AwsJson -FileName "ec2-describe-subnets.json" -Arguments @(
    "ec2", "describe-subnets",
    "--region", $Region,
    "--output", "json"
)

$loadBalancers = Export-AwsJson -FileName "elbv2-describe-load-balancers.json" -Arguments @(
    "elbv2", "describe-load-balancers",
    "--names", $AlbName,
    "--region", $Region,
    "--output", "json"
) -AllowFailure

$targetGroups = Export-AwsJson -FileName "elbv2-describe-target-groups.json" -Arguments @(
    "elbv2", "describe-target-groups",
    "--names", $TargetGroupName,
    "--region", $Region,
    "--output", "json"
) -AllowFailure

if ($null -ne $loadBalancers -and $loadBalancers.LoadBalancers.Count -gt 0) {
    $albArn = $loadBalancers.LoadBalancers[0].LoadBalancerArn
    Export-AwsJson -FileName "elbv2-describe-listeners.json" -Arguments @(
        "elbv2", "describe-listeners",
        "--load-balancer-arn", $albArn,
        "--region", $Region,
        "--output", "json"
    ) | Out-Null

    $listenersPath = Join-Path $backupDir "elbv2-describe-listeners.json"
    $listeners = Get-Content -LiteralPath $listenersPath -Raw | ConvertFrom-Json

    if ($listeners.Listeners.Count -gt 0) {
        foreach ($listener in $listeners.Listeners) {
            $safePort = "$($listener.Port)".Trim()
            Export-AwsJson -FileName "elbv2-describe-rules-port-$safePort.json" -Arguments @(
                "elbv2", "describe-rules",
                "--listener-arn", $listener.ListenerArn,
                "--region", $Region,
                "--output", "json"
            ) | Out-Null
        }
    }
}

if ($null -ne $targetGroups -and $targetGroups.TargetGroups.Count -gt 0) {
    $tgArn = $targetGroups.TargetGroups[0].TargetGroupArn
    Export-AwsJson -FileName "elbv2-describe-target-health.json" -Arguments @(
        "elbv2", "describe-target-health",
        "--target-group-arn", $tgArn,
        "--region", $Region,
        "--output", "json"
    ) | Out-Null
}

$dbInstances = Export-AwsJson -FileName "rds-describe-db-instances.json" -Arguments @(
    "rds", "describe-db-instances",
    "--db-instance-identifier", $DbInstanceIdentifier,
    "--region", $Region,
    "--output", "json"
) -AllowFailure

Export-AwsJson -FileName "rds-describe-db-snapshots-automated.json" -Arguments @(
    "rds", "describe-db-snapshots",
    "--db-instance-identifier", $DbInstanceIdentifier,
    "--snapshot-type", "automated",
    "--region", $Region,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "rds-describe-db-snapshots-manual.json" -Arguments @(
    "rds", "describe-db-snapshots",
    "--db-instance-identifier", $DbInstanceIdentifier,
    "--snapshot-type", "manual",
    "--region", $Region,
    "--output", "json"
) -AllowFailure | Out-Null

$bucketLocation = Export-AwsJson -FileName "s3api-get-bucket-location.json" -Arguments @(
    "s3api", "get-bucket-location",
    "--bucket", $BucketName,
    "--output", "json"
) -AllowFailure

Export-AwsJson -FileName "s3api-get-bucket-versioning.json" -Arguments @(
    "s3api", "get-bucket-versioning",
    "--bucket", $BucketName,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "s3api-get-bucket-policy.json" -Arguments @(
    "s3api", "get-bucket-policy",
    "--bucket", $BucketName,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "s3api-get-bucket-website.json" -Arguments @(
    "s3api", "get-bucket-website",
    "--bucket", $BucketName,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "s3api-list-objects-v2.json" -Arguments @(
    "s3api", "list-objects-v2",
    "--bucket", $BucketName,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "cloudwatch-get-dashboard.json" -Arguments @(
    "cloudwatch", "get-dashboard",
    "--dashboard-name", $DashboardName,
    "--region", $Region,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "backup-list-backup-vaults.json" -Arguments @(
    "backup", "list-backup-vaults",
    "--region", $Region,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "ec2-describe-images-self.json" -Arguments @(
    "ec2", "describe-images",
    "--owners", "self",
    "--region", $Region,
    "--output", "json"
) -AllowFailure | Out-Null

Export-AwsJson -FileName "ec2-describe-snapshots-self.json" -Arguments @(
    "ec2", "describe-snapshots",
    "--owner-ids", "self",
    "--region", $Region,
    "--output", "json"
) -AllowFailure | Out-Null

if ($DownloadS3) {
    $s3BackupDir = Join-Path $backupDir "s3-bucket"
    $null = New-Item -ItemType Directory -Path $s3BackupDir -Force
    $syncResult = Invoke-AwsCli -Arguments @(
        "s3", "sync",
        "s3://$BucketName",
        $s3BackupDir,
        "--region", $Region,
        "--exact-timestamps"
    )
    $syncResult.Output | Set-Content -LiteralPath (Join-Path $backupDir "s3-sync.log") -Encoding utf8
}

if ($CreateRdsSnapshot) {
    $snapshotIdentifier = ("{0}-manual-{1}" -f $DbInstanceIdentifier, (Get-Date -Format "yyyyMMddHHmmss")).ToLowerInvariant()
    $snapshotResult = Invoke-AwsCli -Arguments @(
        "rds", "create-db-snapshot",
        "--db-instance-identifier", $DbInstanceIdentifier,
        "--db-snapshot-identifier", $snapshotIdentifier,
        "--region", $Region,
        "--output", "json"
    )
    $snapshotResult.Output | Set-Content -LiteralPath (Join-Path $backupDir "rds-create-db-snapshot.json") -Encoding utf8
}

Write-Summary -Data @{
    Timestamp            = $timestamp
    Account              = $callerIdentity.Account
    Arn                  = $callerIdentity.Arn
    Region               = $Region
    GitCommit            = $gitCommit
    AlbName              = $AlbName
    TargetGroupName      = $TargetGroupName
    DbInstanceIdentifier = $DbInstanceIdentifier
    BucketName           = $BucketName
    DashboardName        = $DashboardName
    Ec2Names             = $Ec2Names
}

Write-Host "Backup d'architecture termine dans: $backupDir"
if ($DownloadS3) {
    Write-Host "Le contenu S3 a ete telecharge localement."
}
if ($CreateRdsSnapshot) {
    Write-Host "Un snapshot manuel RDS a ete demande. Sa creation continue en arriere-plan sur AWS."
}
