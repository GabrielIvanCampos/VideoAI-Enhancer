#pragma once
#include <filesystem>
#include <string>

namespace VideoAI {
struct ModelSpec { std::string id; std::wstring name; std::string url; std::string sha256; int scale; };
class ModelManager {
public:
    ModelManager();
    std::filesystem::path root() const;
    std::filesystem::path modelPath(const ModelSpec& spec) const;
    bool ensureModel(const ModelSpec& spec, std::wstring& status) const;
private:
    std::filesystem::path root_;
};
}
