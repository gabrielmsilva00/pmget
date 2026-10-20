# Run with Windows PowerShell 5.1; also exercises PowerShell 7 when available.
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('pmget-launchers-' + [guid]::NewGuid())
$savedPath = $env:PATH
$savedBash = $env:PMGET_BASH
$savedPm = $env:PMGET_PM
$savedLocalAppData = $env:LOCALAPPDATA
$checks = 0

function Assert-Equal($Actual, $Expected, [string] $Label) {
    if ($Actual -cne $Expected) { throw "${Label}: expected <$Expected>, got <$Actual>" }
    $script:checks++
}

function Read-Capture {
    $reader = New-Object IO.BinaryReader ([IO.File]::OpenRead($env:PMGET_TEST_CAPTURE))
    try {
        $count = $reader.ReadInt32()
        $values = @()
        for ($i = 0; $i -lt $count; $i++) { $values += $reader.ReadString() }
        return @{ Arguments = $values; Path = $reader.ReadString(); Directory = $reader.ReadString() }
    }
    finally { $reader.Dispose() }
}

try {
    New-Item -ItemType Directory -Path $testDirectory | Out-Null
    $bundle = Join-Path $testDirectory 'folder with spaces'
    New-Item -ItemType Directory -Path $bundle | Out-Null
    foreach ($file in @('pmget', 'pmget.ps1', 'pmget.cmd')) {
        Copy-Item -LiteralPath (Join-Path $repository $file) -Destination $bundle
    }
    $stub = Join-Path $testDirectory 'bash.exe'
    # Native argv capture verifies quoting independently of the launcher code.
    Add-Type -OutputAssembly $stub -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
public class PmgetLauncherCapture {
    public static int Main(string[] args) {
        using (var writer = new BinaryWriter(File.Create(Environment.GetEnvironmentVariable("PMGET_TEST_CAPTURE")))) {
            writer.Write(args.Length);
            foreach (string arg in args) writer.Write(arg);
            writer.Write(Environment.GetEnvironmentVariable("PATH"));
            writer.Write(Environment.CurrentDirectory);
        }
        return int.Parse(Environment.GetEnvironmentVariable("PMGET_TEST_STATUS") ?? "0");
    }
}
'@
    Copy-Item -LiteralPath $stub -Destination (Join-Path $testDirectory 'wsl.exe')
    $env:LOCALAPPDATA = Join-Path $testDirectory 'local app data'
    $fzfLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    New-Item -ItemType Directory -Path $fzfLinks -Force | Out-Null
    Copy-Item -LiteralPath $stub -Destination (Join-Path $fzfLinks 'fzf.exe')
    $env:PMGET_BASH = $stub
    $env:PATH = "$testDirectory;$savedPath"
    $env:PMGET_TEST_CAPTURE = Join-Path $testDirectory 'capture.bin'
    $harness = Join-Path $testDirectory 'invoke.ps1'
    @'
param($Launcher, $Data)
$values = Import-Clixml -LiteralPath $Data
& $Launcher @values
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $harness -Encoding ASCII
    $data = Join-Path $testDirectory 'arguments.xml'
    $hosts = @((Get-Command powershell.exe -CommandType Application).Source)
    $pwsh = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($pwsh) { $hosts += $pwsh.Source }
    foreach ($hostPath in $hosts) {
        $label = Split-Path $hostPath -Leaf
        $values = @('--pm', 'winget', '-c', '-i', 'name with spaces', '', 'literal"quote', 'slash\"quote', 'trailing space\', 'a&b;$(literal)', '%PATH%', 'wow!')
        Export-Clixml -LiteralPath $data -InputObject $values
        $env:PMGET_TEST_STATUS = '37'
        & $hostPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $harness (Join-Path $bundle 'pmget.ps1') $data
        Assert-Equal $LASTEXITCODE 37 "$label native exit status"
        $capture = Read-Capture
        Assert-Equal $capture.Arguments[0] (Join-Path $bundle 'pmget') "$label adjacent script"
        Assert-Equal $capture.Arguments.Count ($values.Count + 1) "$label argument count"
        for ($i = 0; $i -lt $values.Count; $i++) { Assert-Equal $capture.Arguments[$i + 1] $values[$i] "$label argument $i" }
        Assert-Equal $capture.Directory $PWD.ProviderPath "$label working directory"
        Assert-Equal ($capture.Path.StartsWith($testDirectory + ';')) $true "$label runtime utilities on PATH"
        Assert-Equal (($capture.Path -split ';') -contains $fzfLinks) $true "$label finds fzf outside the current PATH"

        # WSL must bypass even an invalid Git Bash override and strip every --wsl.
        $env:PMGET_BASH = Join-Path $testDirectory 'missing-bash.exe'
        $env:PMGET_PM = 'apt'
        $env:PMGET_TEST_STATUS = '42'
        Export-Clixml -LiteralPath $data -InputObject @('--info', 'name with spaces', '--wsl', '--pm', 'apt', '--wsl')
        & $hostPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $harness (Join-Path $bundle 'pmget.ps1') $data
        Assert-Equal $LASTEXITCODE 42 "$label WSL exit status"
        $capture = Read-Capture
        Assert-Equal ($capture.Arguments[0..2] -join ',') '--exec,bash,-c' "$label WSL command"
        Assert-Equal $capture.Arguments[3].Contains("`r") $false "$label WSL command uses Linux newlines"
        Assert-Equal $capture.Arguments[5] (Join-Path $bundle 'pmget') "$label WSL script path"
        Assert-Equal $capture.Arguments[6] apt "$label WSL manager default"
        Assert-Equal ($capture.Arguments[7..10] -join ',') '--info,name with spaces,--pm,apt' "$label WSL forwarded arguments"
        Assert-Equal $capture.Arguments.Count 11 "$label WSL flag removal"
        Assert-Equal (($capture.Path -split ';') -contains $fzfLinks) $false "$label WSL does not use Windows fzf"

        $env:PMGET_TEST_STATUS = '0'
        # Missing launcher dependencies must produce a normal nonzero exit.
        Export-Clixml -LiteralPath $data -InputObject @('--version')
        $ErrorActionPreference = 'Continue'
        & $hostPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $harness (Join-Path $bundle 'pmget.ps1') $data 2>$null
        $ErrorActionPreference = 'Stop'
        Assert-Equal $LASTEXITCODE 1 "$label invalid Bash override"
        $env:PMGET_BASH = $stub
    }

    # Exercise the batch entry point in a real CMD process, including a quoted
    # metacharacter and an empty argument, without CALL's second expansion.
    $batch = Join-Path $testDirectory 'invoke.cmd'
    ('@echo off' + "`r`n" + '"' + (Join-Path $bundle 'pmget.cmd') + '" --info "name & spaces" "" --pm winget' + "`r`nexit /b %errorlevel%`r`n") | Set-Content -LiteralPath $batch -Encoding ASCII
    $env:PMGET_TEST_STATUS = '23'
    & $env:ComSpec /d /c $batch
    Assert-Equal $LASTEXITCODE 23 'CMD exit status'
    $capture = Read-Capture
    Assert-Equal ($capture.Arguments[1..5] -join ',') '--info,name & spaces,,--pm,winget' 'CMD argument forwarding'
    Assert-Equal $capture.Arguments[0] (Join-Path $bundle 'pmget') 'CMD adjacent script'

    Write-Output "Passed $checks Windows launcher checks."
}
finally {
    $env:PATH = $savedPath
    $env:PMGET_BASH = $savedBash
    $env:PMGET_PM = $savedPm
    $env:LOCALAPPDATA = $savedLocalAppData
    Remove-Item Env:PMGET_TEST_CAPTURE, Env:PMGET_TEST_STATUS -ErrorAction SilentlyContinue
    # Validate the resolved target before removing this test's temporary folder.
    $resolved = [IO.Path]::GetFullPath($testDirectory)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temporaryRoot + 'pmget-launchers-', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected cleanup target' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
