# ============================================================
# pre_commit.ps1 - avalanche_flutter_sdk quality gate
# Run before every commit: .\scripts\pre_commit.ps1
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  avalanche_flutter_sdk pre-commit check" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ---- Section 1: Format ----
Write-Host ""
Write-Host "[1/3] dart format --set-exit-if-changed ." -ForegroundColor Yellow
dart format --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Format issues found. Run 'dart format .' to fix." -ForegroundColor Red
    exit 1
}
Write-Host "Format: OK" -ForegroundColor Green

# ---- Section 2: Analyze ----
Write-Host ""
Write-Host "[2/3] dart analyze --fatal-infos" -ForegroundColor Yellow
dart analyze --fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Analysis errors found." -ForegroundColor Red
    exit 1
}
Write-Host "Analyze: OK" -ForegroundColor Green

# ---- Section 3: Test ----
Write-Host ""
Write-Host "[3/3] flutter test" -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Tests failed." -ForegroundColor Red
    exit 1
}
Write-Host "Tests: OK" -ForegroundColor Green

# ---- Done ----
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  All checks passed. Ready to commit." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
