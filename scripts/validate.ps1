<#
.SYNOPSIS
    Validates the dotnet-engineering skill against the Agent Skills format.

.DESCRIPTION
    Checks frontmatter fields and limits, the name/folder match, the SKILL.md line budget,
    that only one SKILL.md exists, and that every internal link resolves.

.EXAMPLE
    ./scripts/validate.ps1
#>

[CmdletBinding()]
param(
    [string]$SkillPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "skills/dotnet-engineering")
)

$ErrorActionPreference = "Stop"
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Error([string]$message) { $script:errors.Add($message) }
function Add-Warning([string]$message) { $script:warnings.Add($message) }

$skillFile = Join-Path $SkillPath "SKILL.md"
if (-not (Test-Path $skillFile)) {
    Write-Host "SKILL.md not found at $skillFile" -ForegroundColor Red
    exit 1
}

$text = [System.IO.File]::ReadAllText($skillFile)
$folderName = Split-Path $SkillPath -Leaf

# --- frontmatter -------------------------------------------------------------
if ($text -match '(?s)^---\r?\n(.*?)\r?\n---') {
    $frontmatter = $Matches[1]
} else {
    Add-Error "SKILL.md has no YAML frontmatter."
    $frontmatter = ""
}

$name = $null
if ($frontmatter -match '(?m)^name:\s*(.+?)\s*$') { $name = $Matches[1] }

if (-not $name) {
    Add-Error "Frontmatter is missing the required 'name' field."
} else {
    if ($name -ne $folderName) { Add-Error "name '$name' does not match the folder name '$folderName'." }
    if ($name.Length -gt 64) { Add-Error "name is $($name.Length) characters; the limit is 64." }
    if ($name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        Add-Error "name '$name' must be lowercase letters, numbers and single hyphens, not starting or ending with a hyphen."
    }
}

$description = $null
if ($frontmatter -match '(?ms)^description:\s*(.+?)(?=^\w[\w-]*:|\z)') { $description = $Matches[1].Trim() }

if (-not $description) {
    Add-Error "Frontmatter is missing the required 'description' field."
} else {
    if ($description.Length -gt 1024) { Add-Error "description is $($description.Length) characters; the limit is 1024." }
    if ($description -match '[<>]') { Add-Error "description contains angle brackets, which are not allowed." }
    if ($description.Length -lt 80) { Add-Warning "description is only $($description.Length) characters; a richer description improves triggering." }
}

# --- body budget -------------------------------------------------------------
$lineCount = (Get-Content $skillFile).Count
if ($lineCount -gt 500) {
    Add-Error "SKILL.md is $lineCount lines; keep it under 500 and move detail into references."
} elseif ($lineCount -gt 450) {
    Add-Warning "SKILL.md is $lineCount lines, close to the 500-line budget."
}

# --- exactly one SKILL.md ----------------------------------------------------
$nested = Get-ChildItem $SkillPath -Recurse -File -Filter "SKILL.md" | Where-Object { $_.FullName -ne (Resolve-Path $skillFile).Path }
foreach ($n in $nested) { Add-Error "Nested SKILL.md found at $($n.FullName); reference entry files must be named README.md." }

# --- links -------------------------------------------------------------------
$mdFiles = Get-ChildItem $SkillPath -Recurse -File -Filter *.md
$linkCount = 0
foreach ($file in $mdFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    foreach ($match in [regex]::Matches($content, '\]\(([^)\s]+)\)')) {
        $target = $match.Groups[1].Value
        # Skip external links and the illustrative paths used inside code examples.
        if ($target -match '^(https?:|mailto:|#|~|/|\$)') { continue }
        $linkCount++
        if ($target -match '\\') { Add-Error "$($file.Name): link '$target' uses a backslash; use forward slashes." }
        $relative = ($target -split '#')[0]
        if (-not $relative) { continue }
        $resolved = Join-Path (Split-Path $file.FullName -Parent) $relative
        if (-not (Test-Path $resolved)) { Add-Error "$($file.Name): broken link '$target'." }
    }
}

# --- reference layout --------------------------------------------------------
$referenceRoot = Join-Path $SkillPath "references"
if (Test-Path $referenceRoot) {
    $refFiles = (Get-ChildItem $referenceRoot -Recurse -File -Filter *.md).Count
    $libraryDirs = (Get-ChildItem (Join-Path $referenceRoot "library") -Directory -ErrorAction SilentlyContinue).Count
    $doctrineFiles = (Get-ChildItem (Join-Path $referenceRoot "doctrine") -File -Filter *.md -ErrorAction SilentlyContinue).Count
    $specialists = (Get-ChildItem (Join-Path $referenceRoot "specialists") -File -Filter *.md -ErrorAction SilentlyContinue).Count
} else {
    Add-Error "references/ folder not found."
    $refFiles = 0; $libraryDirs = 0; $doctrineFiles = 0; $specialists = 0
}

# --- report ------------------------------------------------------------------
Write-Host ""
Write-Host "Skill:         $folderName"
Write-Host "SKILL.md:      $lineCount lines (budget 500)"
Write-Host "description:   $($description.Length) characters (limit 1024)"
Write-Host "doctrine:      $doctrineFiles files"
Write-Host "library:       $libraryDirs topics"
Write-Host "specialists:   $specialists playbooks"
Write-Host "references:    $refFiles markdown files"
Write-Host "internal links:$linkCount checked"
Write-Host ""

foreach ($w in $warnings) { Write-Host "WARNING  $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "ERROR    $e" -ForegroundColor Red }

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "$($errors.Count) error(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Valid." -ForegroundColor Green
exit 0
