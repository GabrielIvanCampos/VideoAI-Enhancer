#include "ModelManager.h"
#include <windows.h>
#include <winhttp.h>
#include <bcrypt.h>
#include <fstream>
#include <vector>
#include <sstream>
#include <iomanip>
#pragma comment(lib,"winhttp.lib")
#pragma comment(lib,"bcrypt.lib")

namespace VideoAI {
ModelManager::ModelManager(){
 wchar_t* local=nullptr; size_t len=0;
 if(_wdupenv_s(&local,&len,L"LOCALAPPDATA")==0 && local){ root_=std::filesystem::path(local)/L"VideoAI Enhancer"/L"models"; free(local); }
 else root_=std::filesystem::temp_directory_path()/L"VideoAI Enhancer"/L"models";
}
std::filesystem::path ModelManager::root() const{return root_;}
std::filesystem::path ModelManager::modelPath(const ModelSpec& s) const{return root_/std::filesystem::path(s.id)/L"model.onnx";}
static std::string sha256(const std::filesystem::path& p){
 BCRYPT_ALG_HANDLE alg=nullptr; BCRYPT_HASH_HANDLE hash=nullptr; DWORD cb=0,obj=0; std::string out;
 if(BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,nullptr,0)!=0) return {};
 if(BCryptGetProperty(alg,BCRYPT_OBJECT_LENGTH,(PUCHAR)&obj,sizeof(obj),&cb,0)!=0){BCryptCloseAlgorithmProvider(alg,0);return{};}
 std::vector<BYTE> ho(obj); std::vector<BYTE> digest(32);
 if(BCryptCreateHash(alg,&hash,ho.data(),obj,nullptr,0,0)!=0){BCryptCloseAlgorithmProvider(alg,0);return{};}
 std::ifstream f(p,std::ios::binary); std::vector<char> buf(1024*1024);
 while(f){f.read(buf.data(),buf.size()); auto n=f.gcount(); if(n>0 && BCryptHashData(hash,(PUCHAR)buf.data(),(ULONG)n,0)!=0){BCryptDestroyHash(hash);BCryptCloseAlgorithmProvider(alg,0);return{};}}
 if(BCryptFinishHash(hash,digest.data(),(ULONG)digest.size(),0)!=0){BCryptDestroyHash(hash);BCryptCloseAlgorithmProvider(alg,0);return{};}
 BCryptDestroyHash(hash); BCryptCloseAlgorithmProvider(alg,0);
 std::ostringstream ss; ss<<std::hex<<std::setfill('0'); for(auto b:digest) ss<<std::setw(2)<<(int)b; return ss.str();
}
static bool download(const std::string& url,const std::filesystem::path& out,std::wstring& status){
 std::string u=url; const std::string pref="https://"; if(u.rfind(pref,0)!=0) return false; u=u.substr(pref.size()); auto slash=u.find('/'); if(slash==std::string::npos) return false; std::wstring host(u.begin(),u.begin()+slash); std::wstring path(u.begin()+slash,u.end());
 HINTERNET ses=WinHttpOpen(L"VideoAI-Enhancer/2.1",WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,WINHTTP_NO_PROXY_NAME,WINHTTP_NO_PROXY_BYPASS,0); if(!ses)return false;
 HINTERNET con=WinHttpConnect(ses,host.c_str(),INTERNET_DEFAULT_HTTPS_PORT,0); if(!con){WinHttpCloseHandle(ses);return false;}
 HINTERNET req=WinHttpOpenRequest(con,L"GET",path.c_str(),nullptr,WINHTTP_NO_REFERER,WINHTTP_DEFAULT_ACCEPT_TYPES,WINHTTP_FLAG_SECURE); if(!req){WinHttpCloseHandle(con);WinHttpCloseHandle(ses);return false;}
 BOOL ok=WinHttpSendRequest(req,WINHTTP_NO_ADDITIONAL_HEADERS,0,WINHTTP_NO_REQUEST_DATA,0,0,0)&&WinHttpReceiveResponse(req,nullptr);
 if(!ok){WinHttpCloseHandle(req);WinHttpCloseHandle(con);WinHttpCloseHandle(ses);return false;}
 DWORD statusCode=0, sz=sizeof(statusCode); WinHttpQueryHeaders(req,WINHTTP_QUERY_STATUS_CODE|WINHTTP_QUERY_FLAG_NUMBER,nullptr,&statusCode,&sz,nullptr); if(statusCode<200||statusCode>=300){WinHttpCloseHandle(req);WinHttpCloseHandle(con);WinHttpCloseHandle(ses);return false;}
 std::ofstream f(out,std::ios::binary); if(!f){WinHttpCloseHandle(req);WinHttpCloseHandle(con);WinHttpCloseHandle(ses);return false;}
 BYTE buf[1024*1024]; DWORD n=0; ULONGLONG total=0;
 do{ if(!WinHttpReadData(req,buf,sizeof(buf),&n)){f.close();DeleteFileW(out.c_str());WinHttpCloseHandle(req);WinHttpCloseHandle(con);WinHttpCloseHandle(ses);return false;} if(n){f.write((char*)buf,n); total+=n; if(total%(10*1024*1024)<n){status=L"Baixando modelo: "+std::to_wstring(total/1024/1024)+L" MB";}} }while(n);
 f.close(); WinHttpCloseHandle(req);WinHttpCloseHandle(con);WinHttpCloseHandle(ses); return true;
}
bool ModelManager::ensureModel(const ModelSpec& s,std::wstring& status) const{
 std::error_code ec; std::filesystem::create_directories(root_/std::filesystem::path(s.id),ec); if(ec){status=L"Não foi possível criar a pasta de modelos.";return false;}
 auto p=modelPath(s); if(std::filesystem::exists(p)){ if(s.sha256.empty()||sha256(p)==s.sha256)return true; std::filesystem::remove(p,ec); }
 auto tmp=p; tmp+=L".download"; std::filesystem::remove(tmp,ec); status=L"Baixando modelo de IA..."; if(!download(s.url,tmp,status)){status=L"Falha no download do modelo.";return false;}
 if(!s.sha256.empty() && sha256(tmp)!=s.sha256){std::filesystem::remove(tmp,ec);status=L"Falha de integridade: SHA-256 do modelo não confere.";return false;}
 std::filesystem::rename(tmp,p,ec); if(ec){std::filesystem::remove(tmp,ec);status=L"Falha ao instalar o modelo.";return false;} status=L"Modelo instalado."; return true;
}
}
