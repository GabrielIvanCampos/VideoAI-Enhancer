#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSCommandPath
$BuildDir = Join-Path $Root 'build'
$BinDir = Join-Path $BuildDir 'bin'
$Log = Join-Path $Root 'build_diagnostic.log'
$ORTDir = Join-Path $Root 'third_party\onnxruntime'

function Write-Log([string]$Message, [string]$Level = 'INFO') {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}

function Stop-Build([string]$Message) {
    throw [System.Exception]::new($Message)
}

function Find-CMake {
    $command = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'CMake\bin\cmake.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'CMake\bin\cmake.exe')
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    return $null
}

function Find-VisualStudio {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) { return $null }
    $installPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installPath) { return $null }
    return [string]$installPath
}

function Invoke-Native([string]$Executable, [string[]]$Arguments, [switch]$RequireConfigureSummary) {
    Write-Log (">>> {0} {1}" -f $Executable, ($Arguments -join ' '))
    $output = @(& $Executable @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) {
        $text = [string]$line
        Write-Host $text
        Add-Content -LiteralPath $Log -Value $text -Encoding UTF8
    }
    if ($exitCode -ne 0) { Stop-Build "Comando falhou com código ${exitCode}: $Executable $($Arguments -join ' ')" }
    if ($RequireConfigureSummary) {
        $textOutput = $output -join "`n"
        if ($textOutput -notmatch '(?m)^-- Configuring done' -or $textOutput -notmatch '(?m)^-- Generating done') {
            Stop-Build 'CMake terminou sem confirmar Configuring done e Generating done.'
        }
    }
}

try {
    Set-Content -LiteralPath $Log -Value "VideoAI Enhancer build`r`nInício: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8
    Write-Log "Projeto: $Root"

    $versionLine = Get-Content -LiteralPath (Join-Path $Root 'VERSION.txt') -TotalCount 1
    if ($versionLine -notmatch '^VideoAI Enhancer V([0-9]+\.[0-9]+\.[0-9]+)$') {
        Stop-Build 'VERSION.txt não contém a versão esperada.'
    }
    $version = $Matches[1]
    Write-Log "Versão: V$version"

    $cmake = Find-CMake
    if (-not $cmake) { Stop-Build 'CMake não foi localizado. Instale CMake 3.24+ e tente novamente.' }
    $cmakeVersion = & $cmake --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -ne 0) { Stop-Build "Falha ao executar CMake em $cmake" }
    Write-Log "CMake: $cmakeVersion ($cmake)"

    $vsRoot = Find-VisualStudio
    if (-not $vsRoot) { Stop-Build 'Visual Studio 2022 Build Tools com o componente MSVC x64 não foi localizado.' }
    $clCandidates = Get-ChildItem -LiteralPath (Join-Path $vsRoot 'VC\Tools\MSVC') -Filter cl.exe -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\bin\\Hostx64\\x64\\cl\.exe$' } |
        Sort-Object FullName -Descending
    if (-not $clCandidates) { Stop-Build "cl.exe x64 não foi localizado na instalação: $vsRoot" }
    Write-Log "MSVC x64: $($clCandidates[0].FullName)"

    $required = @(
        (Join-Path $ORTDir 'include\onnxruntime_cxx_api.h'),
        (Join-Path $ORTDir 'lib\onnxruntime.lib'),
        (Join-Path $ORTDir 'bin\onnxruntime.dll')
    )
    foreach ($file in $required) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Stop-Build "Dependência requerida ausente: $file" }
    }
    Write-Log 'ONNX Runtime: header, LIB e DLL encontrados.'

    $ffmpegLocal = Join-Path $Root 'tools\ffmpeg\ffmpeg.exe'
    if (Test-Path -LiteralPath $ffmpegLocal -PathType Leaf) {
        Write-Log "FFmpeg para cópia junto ao EXE: $ffmpegLocal"
    } else {
        $ffmpegOnPath = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
        if ($ffmpegOnPath) { Write-Log "FFmpeg no PATH: $($ffmpegOnPath.Source)" }
        else { Write-Log 'FFmpeg não está local; a aplicação procurará ao lado do EXE e no PATH.' 'WARN' }
    }

    Invoke-Native -Executable $cmake -Arguments @(
        '-S', $Root, '-B', $BuildDir, '-G', 'Visual Studio 17 2022', '-A', 'x64'
    ) -RequireConfigureSummary

    Invoke-Native -Executable $cmake -Arguments @(
        '--build', $BuildDir, '--config', 'Release', '--clean-first'
    )

    $exe = Join-Path $BinDir 'VideoAI_Enhancer.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { Stop-Build "EXE Release não encontrado no caminho configurado pelo CMake: $exe" }

    $stream = [System.IO.File]::OpenRead($exe)
    try {
        $reader = New-Object System.IO.BinaryReader($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) { Stop-Build 'EXE inválido: assinatura DOS MZ ausente.' }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { Stop-Build 'EXE inválido: assinatura PE ausente.' }
        if ($reader.ReadUInt16() -ne 0x8664) { Stop-Build 'EXE inválido: a arquitetura PE não é x64.' }
    } finally {
        $stream.Dispose()
    }

    $ortDll = Join-Path $BinDir 'onnxruntime.dll'
    if (-not (Test-Path -LiteralPath $ortDll -PathType Leaf)) { Stop-Build "DLL ONNX Runtime não foi copiada ao lado do EXE: $ortDll" }
    Write-Log "EXE Release: $exe ($(Get-Item -LiteralPath $exe).Length bytes)"
    Write-Log "PE x64: válido; onnxruntime.dll: presente; versão da UI: V$version" 'SUCCESS'
    Write-Log 'BUILD RELEASE CONCLUÍDO' 'SUCCESS'
}
catch {
    Write-Host ''
    Write-Host 'BUILD RELEASE: FAIL' -ForegroundColor Red
    Write-Host "Causa: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Detalhes: $($_ | Out-String)" -ForegroundColor DarkRed
    Write-Host "Script: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Yellow
    Write-Host "Log: $Log" -ForegroundColor Yellow
    try { Read-Host 'Pressione ENTER para fechar' } catch { }
    exit 1
}