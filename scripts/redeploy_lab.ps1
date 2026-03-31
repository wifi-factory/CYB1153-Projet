param(
    [switch]$DestroyOnly,
    [switch]$ApplyOnly,
    [switch]$AutoApprove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ToolPath {
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
    if ($command) {
        return $command.Source
    }

    throw "Unable to locate required tool: $CommandName"
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $script:AwsExe @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $null
        }

        throw "AWS CLI command failed: aws $($Arguments -join ' ')"
    }

    $text = ($output -join [Environment]::NewLine).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Invoke-Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $script:AwsExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: aws $($Arguments -join ' ')"
    }
}

function Wait-Until {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [int]$TimeoutSeconds = 900,
        [int]$IntervalSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) {
            Write-Host "$Description : OK"
            return
        }

        Start-Sleep -Seconds $IntervalSeconds
    }

    throw "Timeout while waiting for: $Description"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$infraDir = Join-Path $repoRoot "infra"
$region = "us-east-1"

$script:AwsExe = Get-ToolPath -CommandName "aws" -CandidatePaths @(
    "C:\Program Files\Amazon\AWSCLIV2\aws.exe",
    "C:\Program Files\Amazon\AWSCLI\bin\aws.exe"
)

$terraformExe = Get-ToolPath -CommandName "terraform" -CandidatePaths @(
    "C:\Users\nawfa\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe\terraform.exe",
    "C:\Users\nawfa\AppData\Local\Microsoft\WinGet\Links\terraform.exe"
)

$identity = Invoke-AwsJson -Arguments @("sts", "get-caller-identity", "--output", "json")
Write-Host "Connected to AWS account $($identity.Account) as $($identity.Arn)"

$defaultVpc = Invoke-AwsJson -Arguments @(
    "ec2", "describe-vpcs",
    "--region", $region,
    "--filters", "Name=isDefault,Values=true",
    "--output", "json"
)

if (-not $defaultVpc.Vpcs -or $defaultVpc.Vpcs.Count -eq 0) {
    throw "No default VPC found in region $region."
}

$vpcId = $defaultVpc.Vpcs[0].VpcId

if (-not $ApplyOnly) {
    Write-Host "Destroy phase started for the current CYB1153 lab resources..."

    $loadBalancer = Invoke-AwsJson -Arguments @(
        "elbv2", "describe-load-balancers",
        "--region", $region,
        "--names", "ALB-annuaire",
        "--output", "json"
    ) -AllowFailure

    if ($loadBalancer -and $loadBalancer.LoadBalancers.Count -gt 0) {
        $albArn = $loadBalancer.LoadBalancers[0].LoadBalancerArn
        Invoke-Aws -Arguments @(
            "elbv2", "delete-load-balancer",
            "--region", $region,
            "--load-balancer-arn", $albArn
        )

        Wait-Until -Description "Suppression du load balancer ALB-annuaire" -Condition {
            $check = Invoke-AwsJson -Arguments @(
                "elbv2", "describe-load-balancers",
                "--region", $region,
                "--names", "ALB-annuaire",
                "--output", "json"
            ) -AllowFailure

            return (-not $check) -or (-not $check.LoadBalancers) -or ($check.LoadBalancers.Count -eq 0)
        }
    }

    $targetGroup = Invoke-AwsJson -Arguments @(
        "elbv2", "describe-target-groups",
        "--region", $region,
        "--names", "Group-web",
        "--output", "json"
    ) -AllowFailure

    if ($targetGroup -and $targetGroup.TargetGroups.Count -gt 0) {
        Invoke-Aws -Arguments @(
            "elbv2", "delete-target-group",
            "--region", $region,
            "--target-group-arn", $targetGroup.TargetGroups[0].TargetGroupArn
        )
    }

    $instances = Invoke-AwsJson -Arguments @(
        "ec2", "describe-instances",
        "--region", $region,
        "--filters",
        "Name=tag:Name,Values=Web-1,Web-2",
        "Name=instance-state-name,Values=pending,running,stopping,stopped",
        "--output", "json"
    )

    $instanceIds = @()
    foreach ($reservation in $instances.Reservations) {
        foreach ($instance in $reservation.Instances) {
            $instanceIds += $instance.InstanceId
        }
    }

    if ($instanceIds.Count -gt 0) {
        $terminateArgs = @(
            "ec2", "terminate-instances",
            "--region", $region,
            "--instance-ids"
        ) + $instanceIds
        Invoke-Aws -Arguments $terminateArgs

        $waitArgs = @(
            "ec2", "wait", "instance-terminated",
            "--region", $region,
            "--instance-ids"
        ) + $instanceIds
        Invoke-Aws -Arguments $waitArgs
    }

    $db = Invoke-AwsJson -Arguments @(
        "rds", "describe-db-instances",
        "--region", $region,
        "--db-instance-identifier", "tutorial-db-instance",
        "--output", "json"
    ) -AllowFailure

    if ($db -and $db.DBInstances.Count -gt 0) {
        Invoke-Aws -Arguments @(
            "rds", "delete-db-instance",
            "--region", $region,
            "--db-instance-identifier", "tutorial-db-instance",
            "--skip-final-snapshot",
            "--delete-automated-backups"
        )

        Invoke-Aws -Arguments @(
            "rds", "wait", "db-instance-deleted",
            "--region", $region,
            "--db-instance-identifier", "tutorial-db-instance"
        )
    }

    $bucket = Invoke-AwsJson -Arguments @(
        "s3api", "head-bucket",
        "--bucket", "cyb1153-annuaire-2026"
    ) -AllowFailure

    if ($bucket -ne $null -or $LASTEXITCODE -eq 0) {
        & $script:AwsExe s3 rb "s3://cyb1153-annuaire-2026" --force --region $region
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to delete bucket cyb1153-annuaire-2026."
        }
    }

    foreach ($securityGroupName in @("DB-SG", "Web-SG", "LB-SG")) {
        $securityGroup = Invoke-AwsJson -Arguments @(
            "ec2", "describe-security-groups",
            "--region", $region,
            "--filters",
            "Name=vpc-id,Values=$vpcId",
            "Name=group-name,Values=$securityGroupName",
            "--output", "json"
        ) -AllowFailure

        if (-not $securityGroup -or -not $securityGroup.SecurityGroups -or $securityGroup.SecurityGroups.Count -eq 0) {
            continue
        }

        $groupId = $securityGroup.SecurityGroups[0].GroupId

        for ($attempt = 1; $attempt -le 20; $attempt++) {
            & $script:AwsExe ec2 delete-security-group --region $region --group-id $groupId 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Security group $securityGroupName deleted."
                break
            }

            if ($attempt -eq 20) {
                throw "Unable to delete security group $securityGroupName after multiple attempts."
            }

            Start-Sleep -Seconds 15
        }
    }
}

if (-not $DestroyOnly) {
    Write-Host "Terraform apply phase started..."

    Push-Location $infraDir
    try {
        & $terraformExe init -input=false
        if ($LASTEXITCODE -ne 0) {
            throw "terraform init failed."
        }

        & $terraformExe validate
        if ($LASTEXITCODE -ne 0) {
            throw "terraform validate failed."
        }

        & $terraformExe plan -input=false -out=tfplan
        if ($LASTEXITCODE -ne 0) {
            throw "terraform plan failed."
        }

        if ($AutoApprove) {
            & $terraformExe apply -input=false -auto-approve tfplan
        }
        else {
            & $terraformExe apply -input=false tfplan
        }

        if ($LASTEXITCODE -ne 0) {
            throw "terraform apply failed."
        }
    }
    finally {
        Pop-Location
    }
}
