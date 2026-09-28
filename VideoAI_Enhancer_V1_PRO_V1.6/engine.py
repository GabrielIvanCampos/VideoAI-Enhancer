import os
import sys
import shutil
import subprocess
import tempfile
import urllib.request
import hashlib
import zipfile
import cv2
import torch
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer

# FFmpeg is downloaded automatically on first export when it is not already
# installed next to the EXE or available in PATH. The official FFmpeg site
# points Windows users to gyan.dev for prebuilt binaries.
FFMPEG_ZIP_URL = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
FFMPEG_SHA_URL = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256"

MODEL_URL = {
    2: "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth",
    4: "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth",
}

class VideoProcessor:
    def __init__(self, log):
        self.log = log

    def model_path(self, scale):
        folder = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")),
                              "VideoAI_Enhancer", "models")
        os.makedirs(folder, exist_ok=True)
        return os.path.join(folder, f"RealESRGAN_x{scale}plus.pth")

    def ensure_model(self, scale):
        path = self.model_path(scale)
        # Basic integrity guard: reject obviously incomplete model files.
        if os.path.isfile(path) and os.path.getsize(path) > 2_000_000:
            return path

        if os.path.exists(path):
            try:
                os.remove(path)
            except OSError:
                pass

        self.log("Baixando o modelo de IA (primeira execução)...")
        tmp = path + ".download"
        try:
            if os.path.exists(tmp):
                os.remove(tmp)
            request = urllib.request.Request(
                MODEL_URL[scale],
                headers={"User-Agent": "VideoAI-Enhancer/1.4"}
            )
            with urllib.request.urlopen(request, timeout=60) as response, open(tmp, "wb") as f:
                total = int(response.headers.get("Content-Length", "0") or 0)
                downloaded = 0
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        self.log(f"Download do modelo: {downloaded/total*100:.1f}%")
            if os.path.getsize(tmp) <= 2_000_000:
                raise RuntimeError("O modelo baixado parece incompleto.")
            os.replace(tmp, path)
            return path
        except Exception as exc:
            try:
                if os.path.exists(tmp):
                    os.remove(tmp)
            except OSError:
                pass
            raise RuntimeError(f"Não foi possível baixar o modelo de IA: {exc}") from exc

    def _app_dir(self):
        if getattr(sys, "frozen", False):
            return os.path.dirname(os.path.abspath(sys.executable))
        return os.path.dirname(os.path.abspath(__file__))

    def _ffmpeg_local_path(self):
        folder = os.path.join(
            os.environ.get("LOCALAPPDATA", os.path.expanduser("~")),
            "VideoAI_Enhancer", "tools"
        )
        os.makedirs(folder, exist_ok=True)
        return os.path.join(folder, "ffmpeg.exe")

    def _download_ffmpeg(self):
        path = self._ffmpeg_local_path()
        zip_path = path + ".zip.download"
        sha_path = path + ".sha256.download"
        extract_dir = path + ".extract"

        self.log("FFmpeg não encontrado. Baixando componente de vídeo (primeira exportação)...")
        try:
            for stale in (zip_path, sha_path):
                if os.path.exists(stale):
                    os.remove(stale)
            if os.path.isdir(extract_dir):
                shutil.rmtree(extract_dir, ignore_errors=True)

            request = urllib.request.Request(
                FFMPEG_SHA_URL,
                headers={"User-Agent": "VideoAI-Enhancer/1.6"}
            )
            with urllib.request.urlopen(request, timeout=60) as response, open(sha_path, "wb") as f:
                f.write(response.read())
            expected = open(sha_path, "r", encoding="utf-8", errors="ignore").read().strip().split()[0].lower()
            if len(expected) != 64:
                raise RuntimeError("Checksum SHA-256 do FFmpeg inválido.")

            request = urllib.request.Request(
                FFMPEG_ZIP_URL,
                headers={"User-Agent": "VideoAI-Enhancer/1.6"}
            )
            with urllib.request.urlopen(request, timeout=120) as response, open(zip_path, "wb") as f:
                total = int(response.headers.get("Content-Length", "0") or 0)
                downloaded = 0
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        self.log(f"Download do FFmpeg: {downloaded/total*100:.1f}%")

            sha = hashlib.sha256()
            with open(zip_path, "rb") as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b""):
                    sha.update(chunk)
            if sha.hexdigest().lower() != expected:
                raise RuntimeError("Falha na verificação SHA-256 do FFmpeg.")

            os.makedirs(extract_dir, exist_ok=True)
            with zipfile.ZipFile(zip_path, "r") as zf:
                member = next((n for n in zf.namelist() if n.lower().endswith("/bin/ffmpeg.exe") or n.lower() == "bin/ffmpeg.exe"), None)
                if not member:
                    raise RuntimeError("O pacote do FFmpeg não contém ffmpeg.exe.")
                with zf.open(member) as src, open(path + ".download", "wb") as dst:
                    shutil.copyfileobj(src, dst, length=1024 * 1024)

            if not os.path.isfile(path + ".download") or os.path.getsize(path + ".download") < 5_000_000:
                raise RuntimeError("ffmpeg.exe baixado parece incompleto.")
            os.replace(path + ".download", path)
            self.log("FFmpeg instalado automaticamente.")
            return path
        except Exception as exc:
            for stale in (zip_path, sha_path, path + ".download"):
                try:
                    if os.path.exists(stale):
                        os.remove(stale)
                except OSError:
                    pass
            try:
                if os.path.isdir(extract_dir):
                    shutil.rmtree(extract_dir, ignore_errors=True)
            except OSError:
                pass
            raise RuntimeError(
                "Não foi possível instalar o FFmpeg automaticamente. "
                "Verifique sua conexão com a internet e tente novamente.\n\n" + str(exc)
            ) from exc

    def ffmpeg(self):
        # In a PyInstaller --onefile build, __file__ points to the temporary
        # extraction directory. The installed executable lives elsewhere.
        candidate = os.path.join(self._app_dir(), "ffmpeg.exe")
        if os.path.isfile(candidate):
            return candidate

        candidate = self._ffmpeg_local_path()
        if os.path.isfile(candidate) and os.path.getsize(candidate) > 5_000_000:
            return candidate

        candidate = shutil.which("ffmpeg")
        if candidate:
            return candidate

        return self._download_ffmpeg()

    def process(self, input_path, output_path, model, scale, denoise, sharpen,
                keep_audio, prefer_gpu, progress, stop):
        if not os.path.isfile(input_path):
            raise RuntimeError("O arquivo de entrada não existe.")

        model_path = self.ensure_model(scale)
        cap = cv2.VideoCapture(input_path)
        if not cap.isOpened():
            raise RuntimeError("Não foi possível abrir o vídeo.")

        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        if w <= 0 or h <= 0:
            cap.release()
            raise RuntimeError("Não foi possível identificar a resolução.")

        use_cuda = bool(prefer_gpu and torch.cuda.is_available())
        self.log(f"Entrada: {w}x{h} @ {fps:.2f} FPS")
        self.log("Aceleração: " + ("NVIDIA CUDA" if use_cuda else "CPU"))

        if scale == 2:
            net = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64,
                          num_block=23, num_grow_ch=32, scale=2)
        else:
            net = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64,
                          num_block=23, num_grow_ch=32, scale=4)

        upsampler = RealESRGANer(
            scale=scale, model_path=model_path, model=net,
            tile=256, tile_pad=10, pre_pad=0, half=use_cuda
        )

        fd, temp = tempfile.mkstemp(suffix=".mp4")
        os.close(fd)
        writer = cv2.VideoWriter(
            temp, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w*scale, h*scale)
        )
        if not writer.isOpened():
            cap.release()
            raise RuntimeError("Não foi possível criar o arquivo temporário.")

        i = 0
        try:
            while True:
                if stop():
                    break
                ok, frame = cap.read()
                if not ok:
                    break
                if denoise:
                    frame = cv2.fastNlMeansDenoisingColored(frame, None, 4, 4, 7, 21)
                result, _ = upsampler.enhance(frame, outscale=scale)
                if sharpen:
                    blur = cv2.GaussianBlur(result, (0,0), 1.0)
                    result = cv2.addWeighted(result, 1.10, blur, -0.10, 0)
                writer.write(result)
                i += 1
                if total:
                    pct = i / total * 90
                    progress(pct, f"IA: {i}/{total} frames ({i/total*100:.1f}%)")
        finally:
            cap.release()
            writer.release()

        if stop():
            try: os.remove(temp)
            except OSError: pass
            return

        progress(92, "Codificando MP4 e áudio...")
        ffmpeg = self.ffmpeg()
        cmd = [ffmpeg, "-y", "-i", temp]
        if keep_audio:
            cmd += ["-i", input_path, "-map", "0:v:0", "-map", "1:a?",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "17",
                    "-c:a", "aac", "-b:a", "192k", "-shortest", output_path]
        else:
            cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "17", output_path]
        result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            details = (result.stderr or "").strip()
            if len(details) > 1800:
                details = details[-1800:]
            raise RuntimeError("FFmpeg falhou ao exportar o vídeo.\n\n" + details)
        try:
            os.remove(temp)
        except OSError:
            pass
        progress(100, "Concluído.")
