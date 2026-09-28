import os
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from engine import VideoProcessor

APP_TITLE = "VideoAI Enhancer"

class VideoAIApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("1100x760")
        self.minsize(980, 680)
        self.configure(bg="#0b0e13")
        self.processor = VideoProcessor(self.log)
        self.stop_requested = False
        self._build()

    def _build(self):
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure("TFrame", background="#0b0e13")
        style.configure("TLabel", background="#0b0e13", foreground="#e9edf4", font=("Segoe UI", 10))
        style.configure("Title.TLabel", background="#0b0e13", foreground="white", font=("Segoe UI", 26, "bold"))
        style.configure("Sub.TLabel", background="#0b0e13", foreground="#8d96a5", font=("Segoe UI", 10))
        style.configure("Card.TFrame", background="#151922")
        style.configure("Accent.TButton", background="#6f5cf5", foreground="white", padding=11, font=("Segoe UI", 10, "bold"))
        style.configure("TButton", padding=9, font=("Segoe UI", 10, "bold"))
        style.configure("TCombobox", fieldbackground="#0f131a", background="#0f131a", foreground="white")

        root = ttk.Frame(self, padding=28)
        root.pack(fill="both", expand=True)

        ttk.Label(root, text="VideoAI Enhancer", style="Title.TLabel").pack(anchor="w")
        ttk.Label(root, text="IA para upscale, restauração e melhoria de vídeo", style="Sub.TLabel").pack(anchor="w", pady=(2, 22))

        card = tk.Frame(root, bg="#151922", highlightbackground="#252b36", highlightthickness=1)
        card.pack(fill="x")

        self.input_var = tk.StringVar()
        self.output_var = tk.StringVar()
        self._path_row(card, "Vídeo de entrada", self.input_var, self.select_input)
        self._path_row(card, "Salvar como", self.output_var, self.select_output)

        opts = tk.Frame(card, bg="#151922")
        opts.pack(fill="x", padx=20, pady=18)

        self.model = tk.StringVar(value="Real-ESRGAN x2plus")
        self.scale = tk.StringVar(value="2x")
        self.noise = tk.IntVar(value=0)
        self.sharp = tk.IntVar(value=1)
        self.audio = tk.IntVar(value=1)
        self.gpu = tk.IntVar(value=1)

        self.model_box = self._combo(opts, "Modelo", self.model,
                                     ["Real-ESRGAN x2plus", "Real-ESRGAN x4plus"], 0, 0, 23)
        self.scale_box = self._combo(opts, "Escala", self.scale, ["2x", "4x"], 0, 2, 8)
        self.model.trace_add("write", self._sync_scale_from_model)
        self.scale.trace_add("write", self._sync_model_from_scale)

        for col, row, text, var in [
            (0,1,"Redução de ruído",self.noise),
            (2,1,"Nitidez inteligente",self.sharp),
            (0,2,"Preservar áudio",self.audio),
            (2,2,"Usar NVIDIA CUDA quando disponível",self.gpu),
        ]:
            tk.Checkbutton(opts, text=text, variable=var, bg="#151922", fg="#cbd2de",
                           selectcolor="#0b0e13", activebackground="#151922",
                           activeforeground="white", font=("Segoe UI",10)).grid(
                               row=row, column=col, columnspan=2, sticky="w", pady=7)

        controls = ttk.Frame(root)
        controls.pack(fill="x", pady=18)
        self.start_btn = ttk.Button(controls, text="▶  MELHORAR VÍDEO", style="Accent.TButton", command=self.start)
        self.start_btn.pack(side="left")
        self.stop_btn = ttk.Button(controls, text="■  PARAR", command=self.stop, state="disabled")
        self.stop_btn.pack(side="left", padx=10)

        self.progress = ttk.Progressbar(root, mode="determinate", maximum=100)
        self.progress.pack(fill="x")
        self.status = tk.StringVar(value="Pronto para processar.")
        ttk.Label(root, textvariable=self.status).pack(anchor="w", pady=8)

        preview = tk.Frame(root, bg="#07090c", highlightbackground="#202631", highlightthickness=1)
        preview.pack(fill="both", expand=True)
        self.log_box = tk.Text(preview, bg="#07090c", fg="#b9c2cf", insertbackground="white",
                               relief="flat", font=("Consolas", 9), padx=12, pady=12)
        self.log_box.pack(fill="both", expand=True)
        self.log("VideoAI Enhancer iniciado.")
        self.log("Modo NVIDIA CUDA será usado automaticamente quando disponível.")

    def _path_row(self, parent, label, var, command):
        row = tk.Frame(parent, bg="#151922")
        row.pack(fill="x", padx=20, pady=(18, 0))
        tk.Label(row, text=label, bg="#151922", fg="#cbd2de", width=17, anchor="w").pack(side="left")
        tk.Entry(row, textvariable=var, bg="#0e1117", fg="white", insertbackground="white",
                 relief="flat", font=("Segoe UI", 10)).pack(side="left", fill="x", expand=True, ipady=9, padx=8)
        ttk.Button(row, text="Selecionar", command=command).pack(side="right")

    def _combo(self, parent, label, var, values, row, col, width):
        tk.Label(parent, text=label, bg="#151922", fg="#cbd2de").grid(row=row, column=col, sticky="w")
        box = ttk.Combobox(parent, textvariable=var, values=values, state="readonly", width=width)
        box.grid(row=row, column=col+1, padx=(10,25), sticky="w")
        return box

    def _sync_scale_from_model(self, *_):
        self.scale.set("2x" if "x2" in self.model.get() else "4x")

    def _sync_model_from_scale(self, *_):
        self.model.set("Real-ESRGAN x2plus" if self.scale.get() == "2x" else "Real-ESRGAN x4plus")

    def select_input(self):
        p = filedialog.askopenfilename(
            title="Selecionar vídeo",
            filetypes=[("Vídeos", "*.mp4 *.mov *.mkv *.avi *.webm"), ("Todos", "*.*")]
        )
        if p:
            self.input_var.set(p)
            self.output_var.set(os.path.splitext(p)[0] + "_enhanced.mp4")

    def select_output(self):
        p = filedialog.asksaveasfilename(
            title="Salvar vídeo",
            defaultextension=".mp4",
            filetypes=[("MP4", "*.mp4")]
        )
        if p:
            self.output_var.set(p)

    def log(self, message):
        self.after(0, self._append_log, message)

    def _append_log(self, message):
        self.log_box.insert("end", message + "\n")
        self.log_box.see("end")

    def start(self):
        if not self.input_var.get() or not os.path.isfile(self.input_var.get()):
            messagebox.showwarning("Vídeo", "Selecione um vídeo de entrada válido.")
            return
        if not self.output_var.get():
            self.output_var.set(os.path.splitext(self.input_var.get())[0] + "_enhanced.mp4")
        self.stop_requested = False
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.progress["value"] = 0
        self.status.set("Preparando IA...")
        args = dict(
            input_path=self.input_var.get(),
            output_path=self.output_var.get(),
            model=self.model.get(),
            scale=int(self.scale.get()[0]),
            denoise=bool(self.noise.get()),
            sharpen=bool(self.sharp.get()),
            keep_audio=bool(self.audio.get()),
            prefer_gpu=bool(self.gpu.get()),
            progress=self.update_progress,
            stop=lambda: self.stop_requested,
        )
        threading.Thread(target=self._worker, args=(args,), daemon=True).start()

    def _worker(self, args):
        try:
            self.processor.process(**args)
            if not self.stop_requested:
                self.after(0, lambda: self.finish(True))
            else:
                self.after(0, lambda: self.finish(False))
        except Exception as exc:
            self.log("ERRO: " + repr(exc))
            self.after(0, lambda e=exc: self.show_error(e))

    def update_progress(self, value, text):
        self.after(0, lambda: self._set_progress(value, text))

    def _set_progress(self, value, text):
        self.progress["value"] = value
        self.status.set(text)

    def stop(self):
        self.stop_requested = True
        self.status.set("Finalizando o processamento atual...")
        self.log("Parada solicitada.")

    def finish(self, ok):
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.progress["value"] = 100 if ok else self.progress["value"]
        self.status.set("Concluído." if ok else "Interrompido.")
        if ok:
            messagebox.showinfo("VideoAI Enhancer", "Vídeo processado com sucesso.")

    def show_error(self, exc):
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.status.set("Erro.")
        messagebox.showerror("Erro no processamento", str(exc))

if __name__ == "__main__":
    VideoAIApp().mainloop()
