#pragma once
#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>

namespace VideoAI {
class RenderLog {
public:
    RenderLog();
    ~RenderLog();
    bool open();
    void write(const std::wstring& level, const std::wstring& message);
    std::filesystem::path path() const;
    bool isOpen() const;
private:
    std::filesystem::path path_;
    std::wofstream file_;
    mutable std::mutex mutex_;
};
}
