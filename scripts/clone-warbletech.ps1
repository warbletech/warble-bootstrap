param(
    [switch]$List,
    [switch]$Clean,
    [switch]$Force,
    [string]$Dest = (Join-Path $HOME "warble-enterprise"),
    [int]$Jobs = 6
)

$ErrorActionPreference = "Stop"
$Org = "warbletech"

function Get-RepoGroup {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Visibility
    )
    switch -Regex ($Name) {
        "^(starling-ex|starling-ex-community)$" { return "enterprise" }
        "^(warble-idp-portal|warble-saas-marketplace|warble-founders-gtm)$" { return "internal" }
        "^(ananta|aviika-llm|avinizer\.tech|chirp-ccp|chirpstack-gatesay|cityguide|drona-edtech|petrol-pump-mvp|pramana|surveillance-mvp|warble-future)$" { return "products" }
        default {
            if ($Visibility -eq "private") { return "internal" }
            return "oss"
        }
    }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh is not installed"
    exit 1
}
gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error "gh is not authenticated"
    exit 1
}

foreach ($group in @("enterprise", "internal", "oss", "products")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Dest $group) | Out-Null
}

$json = gh repo list $Org --limit 500 --json name,isPrivate,description,url,updatedAt,primaryLanguage
if ($LASTEXITCODE -ne 0) { throw "gh repo list failed" }
$repos = $json | ConvertFrom-Json
if (-not $repos -or $repos.Count -eq 0) {
    Write-Error "no repositories returned for $Org"
    exit 1
}

$index = New-Object System.Collections.Generic.List[string]
$index.Add("# warbletech repositories") | Out-Null
$index.Add("") | Out-Null
$index.Add("Every repository in https://github.com/orgs/${Org}/repositories.") | Out-Null
$index.Add("Cloned by ``clone-warbletech.ps1``.") | Out-Null
$index.Add("") | Out-Null
$index.Add("Public repos are in ``oss/``. Starling EX is in ``enterprise/``. Vertical apps and satellite sites are in ``products/``. The rest of the private platform is in ``internal/``.") | Out-Null
$index.Add("") | Out-Null

Write-Host "org https://github.com/orgs/${Org}/repositories"
Write-Host "repos $($repos.Count)"
Write-Host "dest $Dest"
Write-Host ""
Write-Host ("{0,-12} {1,-28} {2}" -f "GROUP", "REPO", "URL")

$grouped = @{}
foreach ($repo in $repos) {
    $visibility = if ($repo.isPrivate) { "private" } else { "public" }
    $group = Get-RepoGroup -Name $repo.name -Visibility $visibility
    if (-not $grouped.ContainsKey($group)) { $grouped[$group] = New-Object System.Collections.Generic.List[object] }
    $grouped[$group].Add(@{
        name = $repo.name
        visibility = $visibility
        url = $repo.url
        updated = if ($repo.updatedAt -is [datetime]) { $repo.updatedAt.ToString("yyyy-MM-dd") } else { ([string]$repo.updatedAt).Substring(0, 10) }
        lang = if ($repo.primaryLanguage) { $repo.primaryLanguage.name } else { "—" }
        desc = (($repo.description | ForEach-Object { $_ }) -replace "[\t\r\n]", " " -replace "\|", "/")
        group = $group
    }) | Out-Null
    Write-Host ("{0,-12} {1,-28} {2}" -f $group, $repo.name, $repo.url)
}

foreach ($group in @("enterprise", "internal", "oss", "products")) {
    $index.Add("## $group") | Out-Null
    $index.Add("") | Out-Null
    $index.Add("| Repo | Visibility | Language | Updated | Description |") | Out-Null
    $index.Add("|---|---|---|---|---|") | Out-Null
    foreach ($row in @($grouped[$group])) {
        if (-not $row) { continue }
        $index.Add("| [$($row.name)]($($row.url)) | $($row.visibility) | $($row.lang) | $($row.updated) | $($row.desc) |") | Out-Null
    }
    $index.Add("") | Out-Null
}
$index.Add("Total: $($repos.Count) repositories.") | Out-Null
$index.Add("") | Out-Null
$indexPath = Join-Path $Dest "INDEX.md"
$index -join "`n" | Set-Content -Path $indexPath -Encoding utf8

if ($List) {
    Write-Host ""
    Write-Host "list only; wrote $indexPath"
    exit 0
}

# Cloning is sequential here so a Windows run does not spawn extra paid runners or
# hidden background work. Use the bash script's --jobs flag on Linux/macOS/WSL
# when you want parallel clones.
$fails = New-Object System.Collections.Generic.List[string]
foreach ($repo in $repos) {
    $visibility = if ($repo.isPrivate) { "private" } else { "public" }
    $group = Get-RepoGroup -Name $repo.name -Visibility $visibility
    $path = Join-Path (Join-Path $Dest $group) $repo.name
    if (Test-Path (Join-Path $path ".git")) {
        $dirty = git -C $path status --porcelain
        if ($dirty -and -not $Force) {
            Write-Host "SKIP ${group}/$($repo.name): uncommitted changes (pass -Force to replace)"
            continue
        }
        if ($Clean) {
            Remove-Item -Recurse -Force $path
        } else {
            Write-Host "SKIP ${group}/$($repo.name): already cloned"
            continue
        }
    } elseif (Test-Path $path) {
        Write-Host "FAIL ${group}/$($repo.name): path exists and is not a git checkout"
        $fails.Add($repo.name) | Out-Null
        continue
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    gh repo clone "$Org/$($repo.name)" $path
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK   ${group}/$($repo.name)"
    } else {
        Write-Host "FAIL ${group}/$($repo.name)"
        $fails.Add($repo.name) | Out-Null
    }
}

if ($fails.Count -gt 0) {
    Write-Host "finished with $($fails.Count) failure(s):"
    $fails | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host "finished: $($repos.Count) repositories under $Dest"
