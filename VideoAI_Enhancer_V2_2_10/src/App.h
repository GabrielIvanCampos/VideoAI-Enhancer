#pragma once
#include <windows.h>
#include <atomic>
#include <thread>
#include <string>
#include "ModelManager.h"
#include "Ffmpeg.h"
#include "Enhancer.h"
#include "RenderLog.h"

namespace VideoAI {
class App {
public:
    explicit App(HINSTANCE instance); ~App(); int run(int show);
private:
    HINSTANCE instance_{}; HWND window_{}; HWND progress_{}; HWND phase_{}; HWND metrics_{}; HWND health_{};
    ModelManager models_; Ffmpeg ffmpeg_; std::thread worker_; std::atomic_bool stop_{false}; RenderLog renderLog_;
    static LRESULT CALLBACK wndProc(HWND,UINT,WPARAM,LPARAM); LRESULT handle(HWND,UINT,WPARAM,LPARAM);
    void createControls(); void start(); void stop(); void appendLog(const std::wstring& s); void publish(const std::wstring& level,const std::wstring& message);
};
}
