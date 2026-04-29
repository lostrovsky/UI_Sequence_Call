# ============================================================
# UI Sequence Call -- Build deployment zip from source
# Run from the project root. Produces a versioned zip in deploy/.
# ============================================================

$ErrorActionPreference = "Stop"

$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$STAGE_DIR = "$PROJECT_ROOT\deploy\stage"

# ============================================================
# Determine version from git tags
# ============================================================
Push-Location $PROJECT_ROOT
try {
    $describe = & git describe --tags --always --dirty 2>$null
    if (-not $describe) { $describe = "v0.0.0-dev" }
    $VERSION = $describe
    $COMMIT  = & git rev-parse --short HEAD 2>$null
    if (-not $COMMIT) { $COMMIT = "unknown" }
} finally {
    Pop-Location
}
$BUILD_DATE = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "Version: $VERSION  Commit: $COMMIT  Built: $BUILD_DATE" -ForegroundColor Cyan

$OUTPUT_ZIP = "$PROJECT_ROOT\deploy\ui_sequence_call_$VERSION.zip"

# ============================================================
# Build jar
# ============================================================
Write-Host "Building jar..." -ForegroundColor Cyan
Push-Location $PROJECT_ROOT
try {
    & mvn clean package -DskipTests -q
    if ($LASTEXITCODE -ne 0) { Write-Error "Maven build failed"; exit 1 }
} finally {
    Pop-Location
}

$jar = "$PROJECT_ROOT\target\ui-sequence-call-1.0.0-jar-with-dependencies.jar"
if (-not (Test-Path $jar)) { Write-Error "Built jar not found at $jar"; exit 1 }

# ============================================================
# Stage zip contents
# ============================================================
Write-Host "Staging deployment package..." -ForegroundColor Cyan
if (Test-Path $STAGE_DIR) { Remove-Item $STAGE_DIR -Recurse -Force }
New-Item -Path $STAGE_DIR -ItemType Directory | Out-Null

# Fat jar
Copy-Item $jar "$STAGE_DIR\ui-sequence-call-1.0.0-jar-with-dependencies.jar"

# Properties file -- the in-repo version uses YOUR_* placeholder credentials
# so it's already safe to ship as-is.
Copy-Item "$PROJECT_ROOT\UISequenceCall.properties" "$STAGE_DIR\UISequenceCall.properties"

# Manual-run launcher (lives next to the jar in the install dir).
Copy-Item "$PROJECT_ROOT\run.cmd" "$STAGE_DIR\run.cmd"

# Service scripts and user guide
$deployDst = "$STAGE_DIR\deploy"
New-Item -Path $deployDst -ItemType Directory | Out-Null
Copy-Item "$PROJECT_ROOT\deploy\register_task.ps1"     "$deployDst\"
Copy-Item "$PROJECT_ROOT\deploy\unregister_task.ps1"   "$deployDst\"
Copy-Item "$PROJECT_ROOT\deploy\INSTALL.txt"           "$deployDst\"

# Version metadata
$versionContent = @(
    "VERSION=$VERSION",
    "COMMIT=$COMMIT",
    "BUILD_DATE=$BUILD_DATE"
) -join "`r`n"
Set-Content -Path "$STAGE_DIR\version.txt" -Value $versionContent -NoNewline

# ============================================================
# Compress
# ============================================================
Write-Host "Creating zip..." -ForegroundColor Cyan
if (Test-Path $OUTPUT_ZIP) { Remove-Item $OUTPUT_ZIP }
Compress-Archive -Path "$STAGE_DIR\*" -DestinationPath $OUTPUT_ZIP

Remove-Item $STAGE_DIR -Recurse -Force

$zipSize = [math]::Round((Get-Item $OUTPUT_ZIP).Length / 1MB, 1)
Write-Host "Package created: $OUTPUT_ZIP ($zipSize MB)" -ForegroundColor Green
