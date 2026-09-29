#include "Ffmpeg.h"
#include <windows.h>
#include <winhttp.h>
#include <fstream>
#include <sstream>
#include <regex>
#include <algorithm>
#include <memory>

#pragma comment(lib,"winhttp.lib")

namespace VideoAI {
namespace {
struct ProcessPipe {
    HANDLE process=nullptr, thread=nullptr, read=nullptr, write=nullptr;
    ~ProcessPipe(){close();}
    void close(){
        if(read){CloseHandle(read);read=nullptr;} if(write){CloseHandle(write);write=nullptr;}
        if(thread){CloseHandle(thread);thread=nullptr;} if(process){CloseHandle(process);process=nullptr;}
    }
};
static std::wstring quote(const std::filesystem::path&p){return L"\""+p.wstring()+L"\"";}
static std::wstring utf8w(const std::string&s){if(s.empty())return{};int n=MultiByteToWideChar(CP_UTF8,0,s.data(),(int)s.size(),nullptr,0);if(n<=0){std::wstring o(s.begin(),s.end());return o;}std::wstring o(n,L'\0');MultiByteToWideChar(CP_UTF8,0,s.data(),(int)s.size(),o.data(),n);return o;}
static bool startProcess(const std::wstring& cmd, HANDLE hIn, HANDLE hOut, HANDLE hErr, ProcessPipe& p){
    STARTUPINFOW si{};si.cb=sizeof(si);si.dwFlags=STARTF_USESTDHANDLES;si.hStdInput=hIn;si.hStdOutput=hOut;si.hStdError=hErr;PROCESS_INFORMATION pi{};
    std::vector<wchar_t> mutableCmd(cmd.begin(),cmd.end());mutableCmd.push_back(L'\0');
    if(!CreateProcessW(nullptr,mutableCmd.data(),nullptr,nullptr,TRUE,CREATE_NO_WINDOW,nullptr,nullptr,&si,&pi))return false;
    p.process=pi.hProcess;p.thread=pi.hThread;return true;
}
static bool readExact(HANDLE h,unsigned char*data,size_t n,std::atomic_bool&stop){size_t gotTotal=0;while(gotTotal<n){if(stop.load())return false;DWORD got=0;DWORD want=(DWORD)std::min<size_t>(n-gotTotal,1<<20);if(!ReadFile(h,data+gotTotal,want,&got,nullptr)||got==0)return false;gotTotal+=got;}return true;}
static bool readToken(HANDLE h,std::string&tok,std::atomic_bool&stop){tok.clear();unsigned char c=0;do{if(!readExact(h,&c,1,stop))return false;}while(c==' '||c=='\n'||c=='\r'||c=='\t');while(true){if(c==' '||c=='\n'||c=='\r'||c=='\t')return true;tok.push_back((char)c);if(!readExact(h,&c,1,stop))return false;}}
static bool writeAll(HANDLE h,const unsigned char*data,size_t n,std::atomic_bool&stop){size_t off=0;while(off<n){if(stop.load())return false;DWORD wrote=0;DWORD want=(DWORD)std::min<size_t>(n-off,1<<20);if(!WriteFile(h,data+off,want,&wrote,nullptr)||wrote==0)return false;off+=wrote;}return true;}
}

std::filesystem::path Ffmpeg::locate() const {
    wchar_t mod[MAX_PATH]{};GetModuleFileNameW(nullptr,mod,MAX_PATH);auto p=std::filesystem::path(mod).parent_path()/L"ffmpeg.exe";if(std::filesystem::exists(p))return p;
    p=std::filesystem::path(mod).parent_path().parent_path().parent_path()/L"tools"/L"ffmpeg"/L"ffmpeg.exe";if(std::filesystem::exists(p))return p;
    wchar_t buf[MAX_PATH*2]{};DWORD n=SearchPathW(nullptr,L"ffmpeg.exe",nullptr,(DWORD)std::size(buf),buf,nullptr);if(n&&n<std::size(buf))return std::filesystem::path(buf);return{};
}
bool Ffmpeg::available() const{return !locate().empty();}

bool Ffmpeg::runCapture(const std::wstring& exe,const std::wstring& args,std::string& output,std::atomic_bool*stop,std::wstring& error) const{
    SECURITY_ATTRIBUTES sa{};sa.nLength=sizeof(sa);sa.bInheritHandle=TRUE;HANDLE r=nullptr,w=nullptr;if(!CreatePipe(&r,&w,&sa,0)){error=L"Não foi possível criar o diagnóstico do FFmpeg.";return false;}SetHandleInformation(r,HANDLE_FLAG_INHERIT,0);
    HANDLE nul=CreateFileW(L"NUL",GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,&sa,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);if(nul==INVALID_HANDLE_VALUE){CloseHandle(r);CloseHandle(w);error=L"Não foi possível preparar a saída do FFmpeg.";return false;}
    ProcessPipe p;std::wstring cmd=quote(std::filesystem::path(exe))+L" "+args;
    if(!startProcess(cmd,GetStdHandle(STD_INPUT_HANDLE),nul,w,p)){DWORD e=GetLastError();CloseHandle(nul);CloseHandle(r);CloseHandle(w);error=L"Falha ao iniciar FFmpeg. Código do Windows: "+std::to_wstring(e);return false;}CloseHandle(w);w=nullptr;CloseHandle(nul);
    output.clear();char buf[4096];bool done=false;while(!done){if(stop&&stop->load()){TerminateProcess(p.process,2);error=L"Processamento interrompido pelo usuário.";p.close();CloseHandle(r);return false;}DWORD avail=0;if(PeekNamedPipe(r,nullptr,0,nullptr,&avail,nullptr)&&avail){DWORD got=0;DWORD want=std::min<DWORD>(avail,(DWORD)sizeof(buf));if(ReadFile(r,buf,want,&got,nullptr)&&got)output.append(buf,buf+got);}DWORD wr=WaitForSingleObject(p.process,50);done=(wr==WAIT_OBJECT_0);}
    while(true){DWORD avail=0;if(!PeekNamedPipe(r,nullptr,0,nullptr,&avail,nullptr)||!avail)break;DWORD got=0;DWORD want=std::min<DWORD>(avail,(DWORD)sizeof(buf));if(!ReadFile(r,buf,want,&got,nullptr)||!got)break;output.append(buf,buf+got);}DWORD code=1;GetExitCodeProcess(p.process,&code);CloseHandle(r);r=nullptr;if(code!=0){error=L"FFmpeg retornou código "+std::to_wstring(code)+L". "+utf8w(output);return false;}return true;
}

bool Ffmpeg::probe(const std::filesystem::path&input,VideoInfo&info,std::wstring&error) const{
    auto exe=locate();if(exe.empty()){error=L"FFmpeg não encontrado.";return false;}std::string out;std::wstring runErr;std::wstring args=L"-hide_banner -loglevel info -i "+quote(input)+L" -t 0.01 -f null -";runCapture(exe.wstring(),args,out,nullptr,runErr);
    std::string s=out;
    std::regex res(R"((\d{2,6})x(\d{2,6}))");std::smatch m;bool got=false;std::istringstream iss(s);std::string line;while(std::getline(iss,line)){if(line.find("Video:")!=std::string::npos){if(std::regex_search(line,m,res)){info.width=std::stoi(m[1]);info.height=std::stoi(m[2]);got=true;}std::regex fr(R"((\d+(?:\.\d+)?)\s*fps)");if(std::regex_search(line,m,fr)){info.fps=std::stod(m[1]);}else{std::regex tbr(R"((\d+(?:\.\d+)?)\s*tbr)");if(std::regex_search(line,m,tbr))info.fps=std::stod(m[1]);}break;}}
    std::regex dur(R"(Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?))");if(std::regex_search(s,m,dur)){info.duration=std::stod(m[1])*3600+std::stod(m[2])*60+std::stod(m[3]);}
    if(!got||info.width<=0||info.height<=0){error=L"FFmpeg não conseguiu identificar a resolução do vídeo.";if(!runErr.empty())error+=L" "+runErr;return false;}if(!(info.fps>0&&info.fps<1000))info.fps=30.0;return true;
}

bool Ffmpeg::canUseNvenc(std::wstring&diagnostic) const{
    auto exe=locate();if(exe.empty()){diagnostic=L"FFmpeg não encontrado.";return false;}std::string out;std::wstring err;std::wstring args=L"-hide_banner -loglevel error -f lavfi -i color=size=16x16:rate=1 -frames:v 1 -c:v h264_nvenc -f null -";if(runCapture(exe.wstring(),args,out,nullptr,err))return true;diagnostic=err.empty()?L"NVENC indisponível no FFmpeg/GPU.":err;return false;
}

bool Ffmpeg::decodePpmPipe(const std::filesystem::path&input,const VideoInfo&info,std::atomic_bool&stop,const std::function<bool(int,int,const std::vector<unsigned char>&,std::wstring&)>&onFrame,std::wstring&error) const{
    auto exe=locate();if(exe.empty()){error=L"FFmpeg não encontrado.";return false;}
    SECURITY_ATTRIBUTES sa{};sa.nLength=sizeof(sa);sa.bInheritHandle=TRUE;HANDLE outR=nullptr,outW=nullptr,errR=nullptr,errW=nullptr;if(!CreatePipe(&outR,&outW,&sa,0)||!CreatePipe(&errR,&errW,&sa,0)){error=L"Falha ao criar os canais do FFmpeg.";return false;}SetHandleInformation(outR,HANDLE_FLAG_INHERIT,0);SetHandleInformation(errR,HANDLE_FLAG_INHERIT,0);
    ProcessPipe p;std::wstring args=L"-hide_banner -loglevel error -i "+quote(input)+L" -map 0:v:0 -f image2pipe -vcodec ppm -pix_fmt rgb24 -fps_mode passthrough -";std::wstring cmd=quote(exe)+L" "+args;
    if(!startProcess(cmd,GetStdHandle(STD_INPUT_HANDLE),outW,errW,p)){error=L"Falha ao iniciar o decodificador FFmpeg.";CloseHandle(outR);CloseHandle(outW);CloseHandle(errR);CloseHandle(errW);return false;}CloseHandle(outW);outW=nullptr;CloseHandle(errW);errW=nullptr;
    std::vector<unsigned char> frame;std::string tok;int count=0;
    while(true){if(stop.load()){TerminateProcess(p.process,2);error=L"Processamento interrompido pelo usuário.";break;}if(!readToken(outR,tok,stop))break;if(tok!="P6"){error=L"FFmpeg retornou um frame em formato inesperado.";TerminateProcess(p.process,2);break;}if(!readToken(outR,tok,stop)){error=L"Cabeçalho PPM incompleto.";break;}int w=std::stoi(tok);if(!readToken(outR,tok,stop)){error=L"Cabeçalho PPM incompleto.";break;}int h=std::stoi(tok);if(!readToken(outR,tok,stop)){error=L"Cabeçalho PPM incompleto.";break;}int maxv=std::stoi(tok);if(w<=0||h<=0||maxv!=255){error=L"Dimensões ou profundidade PPM inválidas.";break;}size_t bytes=(size_t)w*h*3;if(bytes>1024ull*1024ull*1024ull){error=L"Frame excede o limite seguro de memória.";break;}frame.resize(bytes);if(!readExact(outR,frame.data(),bytes,stop)){if(stop.load())error=L"Processamento interrompido pelo usuário.";else error=L"FFmpeg encerrou o fluxo de frames antes do fim.";break;}std::wstring cbErr;if(!onFrame(w,h,frame,cbErr)){error=cbErr.empty()?L"O processamento do frame falhou sem diagnóstico.":cbErr;TerminateProcess(p.process,2);break;}count++;}
    while(true){DWORD avail=0;if(!PeekNamedPipe(errR,nullptr,0,nullptr,&avail,nullptr)||!avail)break;char b[4096];DWORD got=0;DWORD want=std::min<DWORD>(avail,(DWORD)sizeof(b));if(!ReadFile(errR,b,want,&got,nullptr)||!got)break;}
    DWORD code=1;WaitForSingleObject(p.process,5000);GetExitCodeProcess(p.process,&code);std::string diag;DWORD avail=0;while(PeekNamedPipe(errR,nullptr,0,nullptr,&avail,nullptr)&&avail){char b[4096];DWORD got=0;DWORD want=std::min<DWORD>(avail,(DWORD)sizeof(b));if(!ReadFile(errR,b,want,&got,nullptr)||!got)break;diag.append(b,b+got);}CloseHandle(outR);CloseHandle(errR);
    if(stop.load())return false;if(!error.empty())return false;if(code!=0){error=L"FFmpeg falhou ao decodificar o vídeo. "+utf8w(diag);return false;}if(count==0){error=L"FFmpeg não entregou nenhum frame de vídeo.";return false;}return true;
}

bool Ffmpeg::encodePpmPipe(const std::filesystem::path&inputOriginal,const std::filesystem::path&output,const VideoInfo&info,bool nvenc,std::atomic_bool&stop,const std::function<bool(const std::vector<unsigned char>&,std::wstring&)>&onFrame,std::wstring&error) const{
    (void)onFrame; // encoding is fed by the companion writer callback in Enhancer via this helper's local pipe mode.
    // This method is intentionally unused in V2.2.7; the streaming encoder lives in Enhancer.cpp to keep the data path contiguous.
    (void)inputOriginal;(void)output;(void)info;(void)nvenc;(void)stop;
    error=L"Internal encoder path not enabled.";return false;
}

bool Ffmpeg::ensureRuntimeFfmpeg(std::wstring&status) const {
    if(available()) return true;
    status=L"FFmpeg não está instalado ao lado do aplicativo nem no PATH.";
    return false;
}
}
