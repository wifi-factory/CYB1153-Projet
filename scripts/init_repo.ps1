param(
    [string]$RemoteUrl = "https://github.com/wifi-factory/CYB1153-Projet.git",
    [string]$BranchName = "main",
    [string]$GitUserName = "Nawfal Taleb",
    [string]$GitUserEmail = "nawfal.taleb@gmail.com"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is not installed or not available in PATH."
}

if (-not (Test-Path -LiteralPath ".git")) {
    git init | Out-Null
}

git branch -M $BranchName | Out-Null
git config user.name $GitUserName
git config user.email $GitUserEmail

$remoteNames = @(git remote)
if ($remoteNames -contains "origin") {
    git remote set-url origin $RemoteUrl
}
else {
    git remote add origin $RemoteUrl
}

Write-Host "Git repository ready on branch '$BranchName' with remote '$RemoteUrl'."
