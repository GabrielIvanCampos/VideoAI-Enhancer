# VideoAI Enhancer V1 PRO

Projeto preparado para gerar um programa Windows instalável, sem Python para o usuário final.

## O que a V1 PRO terá

- Executável Windows standalone
- Instalador Inno Setup
- Atalho na Área de Trabalho
- Real-ESRGAN x2/x4
- NVIDIA CUDA quando disponível
- CPU como fallback
- redução de ruído
- nitidez
- preservação de áudio
- FFmpeg para exportação
- download automático do modelo na primeira execução
- interface gráfica

## Fluxo

1. O desenvolvedor compila com `build_windows.bat`.
2. Coloca `ffmpeg.exe` na pasta.
3. Executa `build_installer.bat`.
4. É criado `installer\VideoAI_Enhancer_Setup.exe`.
5. O usuário final instala e apenas abre o programa.

## Observação

Este ambiente não compila um binário Windows nativo. O projeto contém o processo de build para Windows. O instalador final deve ser produzido em Windows.

Para uma versão futura, podemos adicionar:
- preview antes/depois
- processamento em lote
- interpolação de FPS
- estabilização
- restauração facial
- modelos adicionais
- fila de trabalhos
- histórico
- presets


### V1.1 - Correção BasicSR / torchvision

Corrige o erro `No module named 'torchvision.transforms.functional_tensor'`.
O build agora usa Torch 2.2.2 + Torchvision 0.17.2, aplica um patch de compatibilidade
no BasicSR e testa os imports antes do PyInstaller. Se os imports falharem, o EXE
não é compilado.


### V1.2 - Correção NumPy / PyTorch

O erro `RuntimeError: Numpy is not available` ocorre porque o PyTorch 2.2.2
não é compatível com NumPy 2.x neste conjunto de dependências.

Esta versão fixa `numpy==1.26.4` e testa a versão do NumPy/Torch antes de
compilar. O build não prossegue para o PyInstaller se os imports da IA falharem.


### V1.3 - Correção dos links dos modelos

Os links de download dos pesos Real-ESRGAN estavam incorretos.
Os modelos oficiais usam:
- RealESRGAN_x4plus.pth -> release v0.1.0
- RealESRGAN_x2plus.pth -> release v0.2.1

A V1.3 corrige esses URLs. O erro `HTTP Error 404: Not Found` durante
`Baixando o modelo de IA` era causado diretamente por esses links incorretos.


## V1.4 - Auditoria e correções adicionais

Corrigidos/fortalecidos:
- download dos modelos com User-Agent e timeout;
- download atômico para evitar modelo corrompido após falha;
- mensagem de erro de download mais clara;
- criação segura do arquivo temporário;
- erro do FFmpeg agora mostra detalhes relevantes;
- modelo e escala da interface ficam sincronizados;
- build avisa se `ffmpeg.exe` estiver ausente;
- instalador interrompe com mensagem clara se `ffmpeg.exe` não estiver presente.

### Pontos conhecidos da V1

- A primeira execução ainda baixa o modelo de IA.
- CUDA só será usada se o PyTorch reconhecer a GPU NVIDIA e o driver for compatível.
- O instalador final depende de um `ffmpeg.exe` que deve ser fornecido no pacote.
- A versão atual é um MVP de restauração/upscale; ainda não possui interpolação de FPS, estabilização ou restauração facial.


## V1.6 - Auditoria adicional

Novas correções:
- FFmpeg agora é procurado corretamente ao lado do EXE quando o programa foi empacotado com PyInstaller `--onefile`.
- O build detecta NVIDIA com `nvidia-smi`.
- Com NVIDIA, instala Torch 2.2.2 + Torchvision 0.17.2 pelo índice CUDA 12.1 oficial.
- Sem NVIDIA, instala a variante CPU oficial.
- PyInstaller agora coleta também `torchvision`.
- Evita conflito de instalação de Torch via PyPI.


## FFmpeg automático
A partir da V1.6, o programa não exige `ffmpeg.exe` manualmente. Na primeira exportação, se o FFmpeg não estiver ao lado do executável nem no PATH, o aplicativo baixa automaticamente o pacote Windows Essentials do FFmpeg, valida o SHA-256 e extrai apenas `ffmpeg.exe` para `%LOCALAPPDATA%\VideoAI_Enhancer\tools`.

A página oficial do FFmpeg lista o gyan.dev entre as fontes de builds Windows. O pacote é obtido diretamente do endereço de builds do fornecedor e tem seu SHA-256 validado antes da instalação. Consulte `FFMPEG_SOURCE.txt` para origem e licenciamento.
