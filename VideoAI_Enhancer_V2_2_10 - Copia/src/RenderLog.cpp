#include "RenderLog.h"
#include <windows.h>
#include <chrono>
#include <iomanip>
#include <sstream>

namespace VideoAI {
static std::wstring nowText() {
    SYSTEMTIME st{};
    GetLocalTime(&st);
    wchar_t b[64]{};
    swprintf_s(b, L"%04u-%02u-%02u %02u:%02u:%02u.%03u", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
    return b;
}
static std::wstring safeFileTime() {
    SYSTEMTIME st{};
    GetLocalTime(&st);
    wchar_t b[64]{};
    swprintf_s(b, L"%04u%02u%02u_%02u%02u%02u", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
    return b;
}
RenderLog::RenderLog() = default;
RenderLog::~RenderLog() { std::lock_guard<std::mutex> g(mutex_); if (file_.is_open()) file_.close(); }
bool RenderLog::open() {
    std::lock_guard<std::mutex> g(mutex_);
    if (file_.is_open()) file_.close();
    wchar_t* local = nullptr; size_t len = 0;
    std::filesystem::path base;
    if (_wdupenv_s(&local, &len, L"LOCALAPPDATA") == 0 && local) {
        base = std::filesystem::path(local) / L"VideoAI Enhancer" / L"logs";
        free(local);
    } else {
        base = std::filesystem::temp_directory_path() / L"VideoAI Enhancer" / L"logs";
    }
    std::error_code ec;
    std::filesystem::create_directories(base, ec);
    if (ec) return false;
    path_ = base / (L"render_" + safeFileTime() + L".log");
    file_.open(path_, std::ios::out | std::ios::app);
    if (!file_.is_open()) return false;
    file_ << L"============================================================\n";
    file_ << L"VideoAI Enhancer - Render Log\n";
    file_ << L"Início: " << nowText() << L"\n";
    file_ << L"============================================================\n";
    file_.flush();
    return true;
}
void RenderLog::write(const std::wstring& level, const std::wstring& message) {
    std::lock_guard<std::mutex> g(mutex_);
    if (!file_.is_open()) return;
    file_ << L"[" << nowText() << L"] [" << level << L"] " << message << L"\n";
    file_.flush();
}
std::filesystem::path RenderLog::path() const { std::lock_guard<std::mutex> g(mutex_); return path_; }
bool RenderLog::isOpen() const { std::lock_guard<std::mutex> g(mutex_); return file_.is_open(); }
}
