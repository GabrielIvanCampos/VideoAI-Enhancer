@echo off
setlocal
cd /d "%~dp0"
if not exist "VideoAI_Enhancer.exe" (
  echo VideoAI_Enhancer.exe nao encontrado.
  echo Execute build_windows.bat primeiro.
  pause
  exit /b 1
)
where ISCC >nul 2>&1
if errorlevel 1 (
  echo Inno Setup Compiler (ISCC) nao encontrado.
  echo Instale o Inno Setup e execute este arquivo novamente.
  pause
  exit /b 1
)
echo Criando instalador...
echo O FFmpeg sera baixado automaticamente pela aplicacao na primeira exportacao.
echo.
ISCC installer.iss
pause
