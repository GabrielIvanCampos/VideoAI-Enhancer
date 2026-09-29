# Auditoria V2.2.10

## Correção principal
A V2.2.8 podia abrir o PowerShell e fechar antes de deixar o diagnóstico visível. O launcher foi simplificado para executar uma única instância elevada do Windows PowerShell com `-NoExit` e caminho absoluto do script.

## Mudanças de segurança do build
- `build_windows.ps1` não faz mais autoelevação.
- O UAC é iniciado somente pelo VBS.
- O PowerShell permanece aberto ao terminar, com sucesso ou erro.
- Mensagens de erro usam interpolação segura para evitar problemas com `:` após variáveis.
- Chamadas externas capturam o exit code imediatamente.
- Dependências são executadas por uma função dedicada e o exit code é verificado.
- O build não baixa CMake automaticamente nesta versão; procura CMake no PATH e no Visual Studio Build Tools.
- OpenCV continua fora do build desta linha; não há etapa de download/extracao do OpenCV.

## Limitação
A compilação MSVC/Windows não foi executada neste ambiente Linux. Esta entrega é uma correção estática do fluxo de lançamento e do script de build.
