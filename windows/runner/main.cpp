#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"
#include "win32_window.h"

namespace {

// #3621 — one running copy. The identity provider returns to the app over
// deskilo://auth-callback, and the installer starts deskilo.exe "<link>": a
// second copy would be the one that hears the answer. It hands its link to the
// first copy (found by its class, never by its title) and ends.
constexpr const wchar_t kInstanceMutexName[] =
    L"Local\\DesKiloRunnerSingleInstance";

bool HandOverToRunningCopy() {
  // The first copy may still be creating its window: wait for it a moment.
  for (int attempt = 0; attempt < 30; ++attempt) {
    HWND running = ::FindWindow(kRunnerWindowClassName, nullptr);
    if (running != nullptr) {
      SendAppLink(running);
      if (::IsIconic(running)) {
        ::ShowWindow(running, SW_RESTORE);
      }
      ::SetForegroundWindow(running);
      return true;
    }
    ::Sleep(100);
  }
  return false;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // One copy of the program runs; a second start hands its link over. The
  // handle lives as long as the process.
  HANDLE instance_lock = ::CreateMutexW(nullptr, FALSE, kInstanceMutexName);
  if (instance_lock != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS &&
      HandOverToRunningCopy()) {
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"DesKilo", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
