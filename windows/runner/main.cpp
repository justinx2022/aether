#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <iterator>
#include <string>
#include <utility>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugin.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  std::vector<std::string> filtered_arguments;
  filtered_arguments.reserve(command_line_arguments.size());
  for (const auto& arg : command_line_arguments) {
    if (arg == "--no-enable-impeller" || arg == "--skia") {
      project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
      continue;
    }
    if (arg == "--enable-impeller") {
      project.set_impeller_switch(flutter::ImpellerSwitch::Enabled);
      continue;
    }
    filtered_arguments.push_back(arg);
  }

  wchar_t renderer_env[32] = {};
  const DWORD renderer_len = ::GetEnvironmentVariableW(
      L"SKYSTREAM_RENDERER", renderer_env,
      static_cast<DWORD>(std::size(renderer_env)));
  if (renderer_len > 0 && renderer_len < std::size(renderer_env)) {
    const std::wstring mode(renderer_env, renderer_len);
    if (mode == L"skia") {
      project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
    } else if (mode == L"impeller") {
      project.set_impeller_switch(flutter::ImpellerSwitch::Enabled);
    }
  }

  project.set_dart_entrypoint_arguments(std::move(filtered_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"skystream", origin, size)) {
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
