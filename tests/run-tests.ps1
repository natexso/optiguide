# OptiGuide test runner: structure checks + LuaJIT syntax check + stub harness.
param(
  [string]$AddonDir = "$PSScriptRoot\..\OptiGuide",
  [string]$LuaJit = "$env:LOCALAPPDATA\Programs\LuaJIT\bin\luajit.exe"
)
$ErrorActionPreference = 'Stop'
$logDir = "$PSScriptRoot\logs"; New-Item -ItemType Directory -Force $logDir | Out-Null
$log = "$logDir\test-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$fail = 0
function Log($m) { $m | Tee-Object -FilePath $log -Append }

"=== OptiGuide tests $(Get-Date) ===" | Tee-Object $log

# --- structure checks ---
$toc = Get-Content "$AddonDir\OptiGuide.toc"
$luaFiles = @($toc | Where-Object { $_ -match '\.lua$' } | ForEach-Object { $_.Trim() })
foreach ($f in $luaFiles) {
  if (Test-Path (Join-Path $AddonDir $f)) { Log "PASS toc-file $f" }
  else { Log "FAIL toc-file $f missing"; $fail++ }
}
if ($toc -match '## Interface: 16001') { Log "PASS interface-16001" } else { Log "FAIL interface"; $fail++ }

$haveJit = Test-Path $LuaJit
if (-not $haveJit) { $LuaJit = (Get-Command luajit -ErrorAction SilentlyContinue).Source }
$haveJit = Test-Path $LuaJit

# --- syntax check each file ---
if ($haveJit) {
  foreach ($f in $luaFiles) {
    $full = (Resolve-Path (Join-Path $AddonDir $f)).Path
    $out = & $LuaJit -e "assert(loadfile([[$full]]))" 2>&1
    if ($LASTEXITCODE -eq 0) { Log "PASS syntax $f" }
    else { Log "FAIL syntax $f : $out"; $fail++ }
  }
} else { Log "WARN no luajit - syntax skipped"; $fail++ }

# --- build + run harness bundle ---
$pre = "OptiGuideNS = {}`nADDON_FILES = {}`n"
foreach ($f in $luaFiles) {
  $src = Get-Content (Join-Path $AddonDir $f) -Raw
  $pre += "ADDON_FILES[`"$f`"] = [==[$src]==]`n"
}
$bundle = $pre + (Get-Content "$PSScriptRoot\harness.lua" -Raw)
$bundlePath = "$logDir\bundle.lua"
$bundle | Set-Content $bundlePath -Encoding UTF8

if ($haveJit) {
  $out = & $LuaJit $bundlePath 2>&1 | Out-String
  Log $out.Trim()
  if ($out -match 'RESULT ALL-PASS') { Log "HARNESS: ALL-PASS" }
  else { Log "HARNESS: FAIL"; $fail++ }
}

Log "=== RESULT: $(if($fail){'FAIL ('+$fail+')'}else{'ALL-PASS'}) ==="
exit ([int]($fail -gt 0))
