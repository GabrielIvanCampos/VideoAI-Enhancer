#pragma once
#include <filesystem>
#include <string>
#include <atomic>
#include <functional>
#include <vector>

namespace VideoAI {
struct VideoInfo {
    int width = 0;
    int height = 0;
    double fps = 30.0;
    double duration = 0.0;
};

class Ffmpeg {
public:
    std::filesystem::path locate() const;
    bool available() const;
    bool probe(const std::filesystem::path& input, VideoInfo& info, std::wstring& error) const;
    bool canUseNvenc(std::wstring& diagnostic) const;

    bool decodePpmPipe(const std::filesystem::path& input,
                       const VideoInfo& info,
                       std::atomic_bool& stop,
                       const std::function<bool(int,int,const std::vector<unsigned char>&,std::wstring&)>& onFrame,
                       std::wstring& error) const;

    bool encodePpmPipe(const std::filesystem::path& inputOriginal,
                       const std::filesystem::path& output,
                       const VideoInfo& info,
                       bool nvenc,
                       std::atomic_bool& stop,
                       const std::function<bool(const std::vector<unsigned char>&,std::wstring&)>& onFrame,
                       std::wstring& error) const;

    bool ensureRuntimeFfmpeg(std::wstring& status) const;

private:
    bool runCapture(const std::wstring& exe, const std::wstring& args, std::string& output, std::atomic_bool* stop, std::wstring& error) const;
};
}
