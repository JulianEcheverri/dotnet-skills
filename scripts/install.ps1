<#
.SYNOPSIS
    Installs the dotnet-engineering skill for an agent.

.PARAMETER Target
    Where to install:
      claude-project   <Path>/.claude/skills
      copilot-project  <Path>/.github/skills
      codex-project    <Path>/.agents/skills
      claude-user      ~/.claude/skills
      copilot-user     ~/.copilot/skills
      agents-user      ~/.agents/skills

.PARAMETER Path
    The repository to install into. Required for the project targets.

.PARAMETER Link
    Create a directory junction instead of copying, so the installed skill follows this checkout.

.EXAMPLE
    ./scripts/install.ps1 -Target copilot-project -Path C:\src\my-api

.EXAMPLE
    ./scripts/install.ps1 -Target claude-user -Link
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("claude-project", "copilot-project", "codex-project", "claude-user", "copilot-user", "agents-user")]
    [string]$Target,

    [string]$Path,

    [switch]$Link
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repoRoot "skills/dotnet-engineering"
if (-not (Test-Path (Join-Path $source "SKILL.md"))) {
    throw "Skill not found at $source"
}

$isProjectTarget = $Target.EndsWith("-project")
if ($isProjectTarget -and -not $Path) {
    throw "-Path is required for the '$Target' target."
}
if ($isProjectTarget -and -not (Test-Path $Path)) {
    throw "Path '$Path' does not exist."
}

$userHome = [Environment]::GetFolderPath("UserProfile")

switch ($Target) {
    "claude-project"  { $skillsDir = Join-Path $Path ".claude/skills" }
    "copilot-project" { $skillsDir = Join-Path $Path ".github/skills" }
    "codex-project"   { $skillsDir = Join-Path $Path ".agents/skills" }
    "claude-user"     { $skillsDir = Join-Path $userHome ".claude/skills" }
    "copilot-user"    { $skillsDir = Join-Path $userHome ".copilot/skills" }
    "agents-user"     { $skillsDir = Join-Path $userHome ".agents/skills" }
}

New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
$destination = Join-Path $skillsDir "dotnet-engineering"

if (Test-Path $destination) {
    $existing = Get-Item $destination -Force
    if ($existing.LinkType) {
        Remove-Item $destination -Force
    } else {
        Remove-Item $destination -Recurse -Force
    }
    Write-Host "Replaced the existing installation."
}

# Windows still resolves most paths against the 260-character limit; warn before a copy fails halfway.
$longestRelative = (Get-ChildItem $source -Recurse -File |
    ForEach-Object { $_.FullName.Substring($source.Length) } |
    Measure-Object -Property Length -Maximum).Maximum
if ($destination.Length + $longestRelative -gt 250) {
    Write-Warning "The destination path is long; some files may exceed the Windows path limit. Install closer to the drive root, or use -Link."
}

if ($Link) {
    New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
    Write-Host "Linked $destination -> $source"
} else {
    if ($env:OS -eq "Windows_NT") {
        # robocopy handles long paths and deep trees that Copy-Item refuses.
        $null = robocopy $source $destination /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1
        if ($LASTEXITCODE -ge 8) { throw "Copy failed (robocopy exit code $LASTEXITCODE)." }
    } else {
        Copy-Item $source -Destination $destination -Recurse -Force
    }
    Write-Host "Copied the skill to $destination"
}

$fileCount = (Get-ChildItem $destination -Recurse -File).Count
Write-Host "$fileCount files installed."
Write-Host ""
Write-Host "Invoke it in chat with /dotnet-engineering, or let the agent pick it up automatically on .NET work."

# robocopy reports success with a non-zero code; do not let it become this script's exit code.
exit 0

