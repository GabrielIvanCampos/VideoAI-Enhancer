#requires -Version 5.1
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSCommandPath
$BuildDir = Join-Path $Root 'build'
$DistDir = Join-Path $Root 'dist'
$ToolsDir = Join-Path $Root 'tools'
$ThirdPartyDir = Join-Path $Root 'third_party'
$ORTDir = Join-Path $ThirdPartyDir 'onnxruntime'
$Log = Join-Path $Root 'build_diagnostic.log'
$ErrorActionPreference = 'Stop'

function Log([string]$Message, [string]$Level = 'INFO') {
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}

function Fail([string]$Message) {
    throw [System.Exception]::new($Message)
}

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Fail 'O build precisa ser executado como Administrador. Execute ABRIR_BUILD_DIAGNOSTICO.vbs e aceite o UAC.'
    }
    Log 'Administrador: OK'
}

function Assert-Project {
    $required = @(
        'CMakeLists.txt',
        'src\main.cpp', 'src\App.cpp', 'src\App.h',
        'src\Enhancer.cpp', 'src\Enhancer.h',
        'src\Ffmpeg.cpp', 'src\Ffmpeg.h',
        'src\ModelManager.cpp', 'src\ModelManager.h',
        'src\RenderLog.cpp', 'src\RenderLog.h'
    )
    foreach ($item in $required) {
        $full = Join-Path $Root $item
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Fail "Arquivo do projeto ausente: $item"
        }
    }
    Log 'Arquivos do projeto: OK'
}

function Find-MSVC {
    $roots = @(
        'C:\VideoAI_BuildTools',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools',
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools'
    )
    foreach ($rootPath in $roots) {
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) { continue }
        $vcTools = Join-Path $rootPath 'VC\Tools\MSVC'
        if (-not (Test-Path -LiteralPath $vcTools -PathType Container)) { continue }
        $cl = Get-ChildItem -LiteralPath $vcTools -Filter cl.exe -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cl) { return $rootPath }
    }
    return $null
}

function Ensure-MSVC {
    $vs = Find-MSVC
    if ($vs) {
        Log "Visual Studio/MSVC x64: OK -> $vs"
        return
    }
    Fail 'Visual Studio Build Tools 2022 com MSVC x64 não foi localizado. Instale o componente C++/MSVC x64 e execute novamente.'
}

function Find-CMake {
    $cmd = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $vs = Find-MSVC
    if ($vs) {
        $candidate = Get-ChildItem -LiteralPath $vs -Filter cmake.exe -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    foreach ($p in @('C:\Program Files\CMake\bin\cmake.exe','C:\Program Files (x86)\CMake\bin\cmake.exe')) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
    }
    return $null
}

function Ensure-CMake {
    $cmake = Find-CMake
    if (-not $cmake) {
        Fail 'CMake não foi localizado. Instale o CMake Tools/standalone no Windows e execute novamente.'
    }
    $version = (& $cmake --version 2>&1 | Select-Object -First 1)
    Log "CMake: $version"
    return $cmake
}

function Invoke-External([string]$Exe, [string[]]$Arguments) {
    Log (">>> {0} {1}" -f $Exe, ($Arguments -join ' '))
    & $Exe @Arguments 2>&1 | ForEach-Object {
        $text = [string]$_
        Write-Host $text
        Add-Content -LiteralPath $Log -Value $text -Encoding UTF8
    }
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Fail ("Processo externo retornou código {0}: {1}" -f $code, $Exe)
    }
}

function Test-Internet {
    try {
        $r = Invoke-WebRequest -Uri 'https://github.com' -Method Head -UseBasicParsing -TimeoutSec 20
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) {
            Log 'Internet: OK'
            return
        }
    } catch { }
    Fail 'Não foi possível validar o acesso à internet necessário para baixar o ONNX Runtime.'
}

function Prepare-ONNXRuntime {
    $version = '1.22.0'
    $url = "https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-$version.zip"

    $incDir = Join-Path $ORTDir 'include'
    $libDir = Join-Path $ORTDir 'lib'
    $binDir = Join-Path $ORTDir 'bin'
    $header = Join-Path $incDir 'onnxruntime_cxx_api.h'
    $lib = Join-Path $libDir 'onnxruntime.lib'
    $dll = Join-Path $binDir 'onnxruntime.dll'

    if ((Test-Path -LiteralPath $header -PathType Leaf) -and
        (Test-Path -LiteralPath $lib -PathType Leaf) -and
        (Test-Path -LiteralPath $dll -PathType Leaf)) {
        Log 'ONNX Runtime: OK'
        return
    }

    Log 'Preparando ONNX Runtime 1.22.0...'
    New-Item -ItemType Directory -Force -Path $ThirdPartyDir | Out-Null

    # Remove only this incomplete local dependency tree. Do not touch source files.
    if (Test-Path -LiteralPath $ORTDir -PathType Container) {
        Remove-Item -LiteralPath $ORTDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $ORTDir | Out-Null

    $zip = Join-Path $env:TEMP ("videoai-ort-$version-" + [guid]::NewGuid().ToString('N') + '.zip')
    $extract = Join-Path $env:TEMP ("videoai-ort-extract-" + [guid]::NewGuid().ToString('N'))

    try {
        Log "Baixando: $url"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 900
        if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) {
            Fail 'Download do ONNX Runtime não produziu o arquivo ZIP.'
        }
        $size = (Get-Item -LiteralPath $zip).Length
        if ($size -lt 1000000) {
            Fail "ZIP do ONNX Runtime parece incompleto: $size bytes."
        }
        Log ("Download ONNX Runtime recebido: {0:N1} MB" -f ($size / 1MB))

        New-Item -ItemType Directory -Force -Path $extract | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        # Do not assume a fixed ZIP root or folder layout. Find the actual files.
        $headerFile = Get-ChildItem -LiteralPath $extract -Filter 'onnxruntime_cxx_api.h' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        $libFile = Get-ChildItem -LiteralPath $extract -Filter 'onnxruntime.lib' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        $dllFile = Get-ChildItem -LiteralPath $extract -Filter 'onnxruntime.dll' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($null -eq $headerFile) { Fail 'ONNX Runtime extraído, mas onnxruntime_cxx_api.h não foi encontrado.' }
        if ($null -eq $libFile) { Fail 'ONNX Runtime extraído, mas onnxruntime.lib não foi encontrado.' }
        if ($null -eq $dllFile) { Fail 'ONNX Runtime extraído, mas onnxruntime.dll não foi encontrado.' }

        Log "ONNX header encontrado: $($headerFile.FullName)"
        Log "ONNX LIB encontrado: $($libFile.FullName)"
        Log "ONNX DLL encontrado: $($dllFile.FullName)"

        $srcInc = $headerFile.Directory
        $srcLib = $libFile.Directory
        $srcBin = $dllFile.Directory

        New-Item -ItemType Directory -Force -Path $incDir,$libDir,$binDir | Out-Null
        Copy-Item -Path (Join-Path $srcInc '*') -Destination $incDir -Recurse -Force
        Copy-Item -LiteralPath $libFile.FullName -Destination $lib -Force
        Copy-Item -LiteralPath $dllFile.FullName -Destination $dll -Force

        if (-not (Test-Path -LiteralPath $header -PathType Leaf)) { Fail 'Falha ao instalar o header do ONNX Runtime.' }
        if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) { Fail 'Falha ao instalar a biblioteca onnxruntime.lib.' }
        if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { Fail 'Falha ao instalar o DLL onnxruntime.dll.' }

        Log 'ONNX Runtime: OK'
    }
    finally {
        if (Test-Path -LiteralPath $extract -PathType Container) { Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $zip -PathType Leaf) { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
    }
}

function Ensure-Dependencies {
    Prepare-ONNXRuntime
}

function Build([string]$CMakeExe) {
    if (Test-Path -LiteralPath $BuildDir -PathType Container) {
        Remove-Item -LiteralPath $BuildDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

    Invoke-External $CMakeExe @('-S', $Root, '-B', $BuildDir, '-G', 'Visual Studio 17 2022', '-A', 'x64', '-DCMAKE_CXX_STANDARD=20')
    Invoke-External $CMakeExe @('--build', $BuildDir, '--config', 'Release', '--parallel')
}

function Validate {
    $exe = Join-Path $BuildDir 'bin\Release\VideoAI_Enhancer.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        $alt = Join-Path $BuildDir 'bin\VideoAI_Enhancer.exe'
        if (Test-Path -LiteralPath $alt -PathType Leaf) { $exe = $alt }
        else { Fail "EXE não encontrado após compilação: $exe" }
    }

    if (Test-Path -LiteralPath $DistDir -PathType Container) {
        Remove-Item -LiteralPath $DistDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    Copy-Item -LiteralPath $exe -Destination (Join-Path $DistDir 'VideoAI_Enhancer.exe') -Force

    $ortDll = Join-Path $ORTDir 'bin\onnxruntime.dll'
    if (-not (Test-Path -LiteralPath $ortDll -PathType Leaf)) {
        Fail "onnxruntime.dll não foi preparado: $ortDll"
    }
    Copy-Item -LiteralPath $ortDll -Destination (Join-Path $DistDir 'onnxruntime.dll') -Force

    Log 'BUILD CONCLUÍDO COM SUCESSO' 'SUCCESS'
    Write-Host "EXE: $(Join-Path $DistDir 'VideoAI_Enhancer.exe')"
}

try {
    Set-Content -LiteralPath $Log -Value "VideoAI Enhancer V2.2.10`r`nInicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8
    Write-Host '============================================================'
    Write-Host 'VideoAI Enhancer V2.2.10 Native'
    Write-Host 'BUILD WINDOWS - POWERSHELL'
    Write-Host '============================================================'

    Assert-Admin
    Assert-Project
    Test-Internet
    Ensure-MSVC
    $cmake = Ensure-CMake
    Ensure-Dependencies
    Build -CMakeExe $cmake
    Validate
}
catch {
    $message = if ($_.Exception) { $_.Exception.Message } else { [string]$_ }
    Write-Host ''
    Write-Host 'BUILD NÃO CONCLUÍDO' -ForegroundColor Red
    Write-Host "CAUSA PRINCIPAL: $message" -ForegroundColor Red
    Write-Host "Log: $Log" -ForegroundColor Yellow
    try { Log "CAUSA PRINCIPAL: $message" 'ERROR' } catch { }
}

Read-Host 'Pressione ENTER para fechar'
