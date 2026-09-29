#include "App.h"
#include <windows.h>

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int nCmdShow) {
    VideoAI::App app(hInstance);
    return app.run(nCmdShow);
}
