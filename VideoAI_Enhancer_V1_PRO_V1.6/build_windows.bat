@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title VideoAI Enhancer - Build Profissional

echo ==========================================
echo     VIDEOAI ENHANCER - BUILD V1 PRO
echo ==========================================
echo.

set "PY="
where py >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%P in ('py -3.11 -c "import sys;print(sys.executable)" 2^>nul') do set "PY=%%P"
)
if not defined PY where python >nul 2>&1
if not defined PY (
  for /f "delims=" %%P in ('python -c "import sys;print(sys.executable)" 2^>nul') do set "PY=%%P"
)

if not defined PY (
  echo [ERRO] Python 3.11 nao encontrado.
  echo Instale Python 3.11 x64 e marque Add Python to PATH.
  pause
  exit /b 1
)

if exist .venv rmdir /s /q .venv
"%PY%" -m venv .venv
if errorlevel 1 goto fail
set "VPY=%CD%\.venv\Scripts\python.exe"

"%VPY%" -m pip install --upgrade pip
if errorlevel 1 goto fail

echo.
echo Instalando dependencias base...
"%VPY%" -m pip install --upgrade pip
if errorlevel 1 goto fail
"%VPY%" -m pip install opencv-python>=4.9 numpy==1.26.4 basicsr>=1.4.2 facexlib>=0.3.0 gfpgan>=1.3.8 realesrgan>=0.3.0 pyinstaller>=6.10
if errorlevel 1 goto fail

echo.
where nvidia-smi >nul 2>&1
if not errorlevel 1 (
  echo NVIDIA detectada - instalando PyTorch CUDA 12.1...
  "%VPY%" -m pip install torch==2.2.2 torchvision==0.17.2 --index-url https://download.pytorch.org/whl/cu121
) else (
  echo NVIDIA nao detectada - instalando PyTorch CPU...
  "%VPY%" -m pip install torch==2.2.2 torchvision==0.17.2 --index-url https://download.pytorch.org/whl/cpu
)
if errorlevel 1 goto fail

echo.
echo Fixando NumPy compativel com PyTorch 2.2.2...
"%VPY%" -m pip uninstall -y numpy >nul 2>&1
"%VPY%" -m pip install numpy==1.26.4
if errorlevel 1 goto fail

echo.
echo Corrigindo compatibilidade BasicSR + torchvision...
"%VPY%" patch_basicsr.py
if errorlevel 1 goto fail

echo.
echo Testando bibliotecas de IA...
"%VPY%" -c "import numpy, torch; print('NumPy', numpy.__version__); print('Torch', torch.__version__)"
if errorlevel 1 goto fail
"%VPY%" -c "import torch, torchvision, basicsr, realesrgan; print('IMPORTS OK')"
if errorlevel 1 goto fail

echo.
echo FFmpeg: o programa fara o download automatico na primeira exportacao.
echo Nao e necessario colocar ffmpeg.exe manualmente.
echo.
echo Criando executavel...
"%VPY%" -m PyInstaller --noconfirm --clean --onefile --windowed ^
 --name VideoAI_Enhancer ^
 --collect-all realesrgan ^
 --collect-all basicsr ^
 --collect-all facexlib ^
 --collect-all gfpgan ^
 --collect-all torch ^
 --collect-all torchvision ^
 --hidden-import=cv2 ^
 --hidden-import=numpy ^
 app.py
if errorlevel 1 goto fail

if not exist "dist\VideoAI_Enhancer.exe" goto fail
copy /Y "dist\VideoAI_Enhancer.exe" "VideoAI_Enhancer.exe" >nul
if errorlevel 1 goto fail

echo.
echo EXE GERADO:
echo %CD%\VideoAI_Enhancer.exe
echo.
echo O instalador nao exige ffmpeg.exe manualmente.
echo O FFmpeg sera instalado automaticamente na primeira exportacao.
pause
exit /b 0

:fail
echo.
echo [ERRO] A compilacao falhou. O EXE nao foi considerado valido.
pause
exit /b 1
