#pragma once
#include <string>
#include <filesystem>
#include <functional>
#include <atomic>
#include <vector>
#include "Ffmpeg.h"
#include <onnxruntime_cxx_api.h>

namespace VideoAI {
struct EnhanceConfig { int scale=4; int tile=256; int tilePad=16; float denoise=0.0f; float detail=0.0f; float sharpen=0.0f; };
class Enhancer {
public:
    Enhancer();
    bool process(const std::filesystem::path& input,
                 const std::filesystem::path& output,
                 const std::filesystem::path& model,
                 const std::filesystem::path& ffmpeg,
                 const VideoInfo& info,
                 bool nvenc,
                 const EnhanceConfig& cfg,
                 const std::function<void(const std::wstring&)>& progress,
                 std::atomic_bool& stop,
                 std::wstring& errorOut);
private:
    struct Frame { int w=0,h=0; std::vector<unsigned char> rgb; };
    Ort::Env env_;
    Ort::SessionOptions opts_;
    std::unique_ptr<Ort::Session> session_;
    bool load(const std::filesystem::path&, std::wstring&);
    Frame inferTile(const Frame&, const EnhanceConfig&);
    static Frame crop(const Frame&,int,int,int,int);
    static void copyCrop(const Frame&,Frame&,int,int,int,int,int,int);
    static void downsample2x(const Frame&,Frame&);
};
}
