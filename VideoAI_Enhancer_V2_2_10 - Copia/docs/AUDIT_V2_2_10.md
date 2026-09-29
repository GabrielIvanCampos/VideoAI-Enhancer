# VideoAI Enhancer V2.2.10 — Audit

## Objective
Eliminar os pontos frágeis do build PowerShell que estavam causando falhas durante a preparação do ONNX Runtime.

## Principais mudanças
- O build usa um único processo PowerShell.
- `build_windows.ps1` não chama `powershell.exe` para executar outro script de dependências.
- O script de dependências separado foi removido.
- O ONNX Runtime é preparado diretamente pelo `build_windows.ps1`.
- O ZIP do ONNX Runtime não depende mais de uma pasta raiz ou subpastas fixas (`include/lib/bin`) para ser reconhecido.
- Após a extração, o build procura recursivamente os artefatos reais: `onnxruntime_cxx_api.h`, `onnxruntime.lib` e `onnxruntime.dll`.
- O diretório raiz do projeto recebe uma estrutura padronizada `third_party/onnxruntime/include`, `lib`, `bin`.
- Instalação parcial/corrompida do ONNX Runtime é descartada antes de uma nova tentativa.
- Erros de download, extração e validação são reportados como causa principal única.
- Removida a dependência do OpenCV na V2 Native atual.
- Corrigido o número da versão no CMake para 2.2.10.

## Limitação
A compilação MSVC/Windows não é executada neste ambiente Linux. A validação aqui é estrutural/estática; o teste final de build deve ocorrer no Windows.
