# Native Windows entry point. Keep this file beside the pmget Bash script.
# No param block: all options belong to pmget, including --help and --wsl.
$ErrorActionPreference = 'Stop'
$pmgetArguments = @($args)

function Find-PmgetBash {
    if ($env:PMGET_BASH) {
        if (-not (Test-Path -LiteralPath $env:PMGET_BASH -PathType Leaf)) {
            throw "PMGET_BASH does not point to a Bash executable: $env:PMGET_BASH"
        }
        return (Resolve-Path -LiteralPath $env:PMGET_BASH).ProviderPath
    }

    $roots = @()
    foreach ($key in @('HKCU:\SOFTWARE\GitForWindows', 'HKLM:\SOFTWARE\GitForWindows', 'HKLM:\SOFTWARE\WOW6432Node\GitForWindows')) {
        $installation = Get-ItemProperty -LiteralPath $key -Name InstallPath -ErrorAction SilentlyContinue
        if ($installation) { $roots += $installation.InstallPath }
    }
    $gitCommand = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gitCommand) { $roots += Split-Path (Split-Path $gitCommand.Source -Parent) -Parent }
    foreach ($base in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) { $roots += Join-Path $base 'Git' }
    }
    if ($env:LOCALAPPDATA) { $roots += Join-Path $env:LOCALAPPDATA 'Programs\Git' }

    foreach ($root in $roots) {
        foreach ($relative in @('bin\bash.exe', 'usr\bin\bash.exe')) {
            $candidate = Join-Path $root $relative
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    foreach ($candidate in @(Get-Command bash.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
        # Windows' legacy bash.exe launches WSL; it is not a native Bash runtime.
        if ($env:SystemRoot -and $candidate.Source.StartsWith($env:SystemRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
        return $candidate.Source
    }
    throw 'Git Bash was not found. Install Git for Windows, set PMGET_BASH to bash.exe, or use --wsl with an installed WSL distribution.'
}

function ConvertTo-PmgetNativeArgument([string] $Value) {
    # Windows PowerShell 5.1 uses .NET Framework, which lacks ArgumentList.
    # Escape using the Windows argv rules, including quotes and trailing slashes.
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Find-PmgetFzfDirectories {
    # Package managers may have just updated the saved PATH while the calling
    # PowerShell still has its old environment. Search their standard links.
    $candidates = @()
    if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links' }
    if ($env:ProgramData) { $candidates += Join-Path $env:ProgramData 'Microsoft\WinGet\Links' }
    if ($env:USERPROFILE) {
        $candidates += Join-Path $env:USERPROFILE 'scoop\shims'
        $candidates += Join-Path $env:USERPROFILE '.fzf\bin'
    }
    if ($env:SCOOP) { $candidates += Join-Path $env:SCOOP 'shims' }
    if ($env:ChocolateyInstall) { $candidates += Join-Path $env:ChocolateyInstall 'bin' }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'fzf.exe') -PathType Leaf) { $candidate }
    }
}

try {
    $scriptPath = Join-Path $PSScriptRoot 'pmget'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "The pmget Bash script is missing. Keep pmget, pmget.ps1, and pmget.cmd in the same folder: $PSScriptRoot"
    }
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.UseShellExecute = $false
    # Inherit the current console, standard input/output, and working directory.
    if ($PWD.Provider.Name -eq 'FileSystem') { $startInfo.WorkingDirectory = $PWD.ProviderPath }
    if ($pmgetArguments -ccontains '--wsl') {
        $wsl = Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $wsl) { throw '--wsl requires WSL and an installed Linux distribution.' }
        $startInfo.FileName = $wsl.Source
        $wslCommand = @'
script_path=$(wslpath -u "$1") || exit $?
export PMGET_PM="$2"
shift 2
exec bash "$script_path" "$@"
'@
        $wslCommand = $wslCommand.Replace("`r`n", "`n")
        $nativeArguments = @('--exec', 'bash', '-c', $wslCommand, 'pmget-wsl', $scriptPath, [string] $env:PMGET_PM)
        $nativeArguments += @($pmgetArguments | Where-Object { $_ -cne '--wsl' })
    }
    else {
        $startInfo.FileName = Find-PmgetBash
        $bashDirectory = Split-Path $startInfo.FileName -Parent
        $gitDirectory = Split-Path $bashDirectory -Parent
        if ((Split-Path $gitDirectory -Leaf) -eq 'usr') { $gitDirectory = Split-Path $gitDirectory -Parent }
        $utilityDirectory = Join-Path $gitDirectory 'usr\bin'
        $startInfo.EnvironmentVariables['PATH'] = "$bashDirectory;$utilityDirectory;$env:PATH"
        foreach ($directory in Find-PmgetFzfDirectories) {
            $startInfo.EnvironmentVariables['PATH'] += ";$directory"
        }
        $nativeArguments = @($scriptPath) + $pmgetArguments
    }
    if ($startInfo.PSObject.Properties['ArgumentList']) {
        foreach ($argument in $nativeArguments) { $startInfo.ArgumentList.Add([string] $argument) }
    }
    else {
        $startInfo.Arguments = ($nativeArguments | ForEach-Object { ConvertTo-PmgetNativeArgument ([string] $_) }) -join ' '
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()
    $status = $process.ExitCode
    $process.Dispose()
    exit $status
}
catch {
    [Console]::Error.WriteLine('pmget: ' + $_.Exception.Message)
    exit 1
}
