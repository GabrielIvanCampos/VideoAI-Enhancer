# VideoAI Enhancer V2.2.10

## Sobre
Versão focada em estabilizar o sistema de build Windows em PowerShell e eliminar as falhas repetidas na preparação das dependências.

## Principais melhorias
- Build em um único processo PowerShell.
- Preparação do ONNX Runtime integrada ao próprio build.
- Detecção recursiva dos arquivos reais do ONNX Runtime após a extração.
- Tratamento seguro de instalações parciais.
- Diagnóstico de erro preservando a causa principal.
- OpenCV removido da cadeia de dependências desta arquitetura Native.
- CMakeLists atualizado para a versão 2.2.10.

## Status
Development Release — ainda requer compilação e teste no Windows.
