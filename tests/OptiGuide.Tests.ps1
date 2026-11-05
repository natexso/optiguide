# Pester suite for OptiGuide. Run: Invoke-Pester ./tests/OptiGuide.Tests.ps1
BeforeAll {
    $AddonDir = Resolve-Path "$PSScriptRoot\..\OptiGuide"
    $LuaJit = "$env:LOCALAPPDATA\Programs\LuaJIT\bin\luajit.exe"
    if (-not (Test-Path $LuaJit)) { $LuaJit = (Get-Command luajit -ErrorAction SilentlyContinue).Source }
    $toc = Get-Content "$AddonDir\OptiGuide.toc"
    $luaFiles = @($toc | Where-Object { $_ -match '\.lua$' } | ForEach-Object { $_.Trim() })
}

Describe "OptiGuide structure" {
    It "targets interface 16001 (forever client)" {
        $toc | Should -Match '## Interface: 16001'
    }
    It "every toc lua file exists" {
        foreach ($f in $luaFiles) { Test-Path (Join-Path $AddonDir $f) | Should -BeTrue }
    }
    It "declares saved variables" {
        $toc | Should -Match 'SavedVariables'
    }
}

Describe "Lua syntax" {
    foreach ($f in $luaFiles) {
        It "$f parses" {
            $full = (Resolve-Path (Join-Path $AddonDir $f)).Path
            & $LuaJit -e "assert(loadfile([[$full]]))"
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Stub harness" {
    It "all harness checks pass" {
        $pre = "OptiGuideNS = {}`nADDON_FILES = {}`n"
        foreach ($f in $luaFiles) {
            $s = Get-Content (Join-Path $AddonDir $f) -Raw
            $pre += "ADDON_FILES[`"$f`"] = [==[$s]==]`n"
        }
        $bundle = $pre + (Get-Content "$PSScriptRoot\harness.lua" -Raw)
        $bp = "$PSScriptRoot\logs\bundle.lua"
        $bundle | Set-Content $bp
        (& $LuaJit $bp | Out-String) | Should -Match 'RESULT ALL-PASS'
    }
}
