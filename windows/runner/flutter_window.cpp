#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

#include <flutter/standard_method_codec.h>
#include <mmsystem.h>

#include <set>
#include <variant>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetupDisplayChannel();
  SetHighRefreshMode(true);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Show is handled by Dart's window_manager to prevent flashing/ghosting on startup.
    // this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetupDisplayChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) return;
  display_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "dev.akash.skystream/display",
          &flutter::StandardMethodCodec::GetInstance());

  display_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setHighRefreshRate") {
          bool enabled = true;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto it = args->find(flutter::EncodableValue("enabled"));
            if (it != args->end()) {
              if (const auto* flag = std::get_if<bool>(&it->second)) {
                enabled = *flag;
              }
            }
          }
          SetHighRefreshMode(enabled);
          result->Success(flutter::EncodableValue(QueryDisplayInfo()));
        } else if (call.method_name() == "getDisplayInfo") {
          result->Success(flutter::EncodableValue(QueryDisplayInfo()));
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::SetHighRefreshMode(bool enabled) {
  high_refresh_enabled_ = enabled;
  if (enabled && !timer_period_active_) {
    if (timeBeginPeriod(1) == TIMERR_NOERROR) {
      timer_period_active_ = true;
    }
  } else if (!enabled && timer_period_active_) {
    timeEndPeriod(1);
    timer_period_active_ = false;
  }
}

flutter::EncodableMap FlutterWindow::QueryDisplayInfo() {
  double current_hz = 60.0;
  std::set<DWORD> rates;

  HWND hwnd = GetHandle();
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFOEXW mi = {};
  mi.cbSize = sizeof(MONITORINFOEXW);

  const wchar_t* device_name = nullptr;
  if (monitor != nullptr && GetMonitorInfoW(monitor, &mi)) {
    device_name = mi.szDevice;
  }

  DEVMODEW cur_mode = {};
  cur_mode.dmSize = sizeof(DEVMODEW);
  if (EnumDisplaySettingsW(device_name, ENUM_CURRENT_SETTINGS, &cur_mode) &&
      cur_mode.dmDisplayFrequency >= 48u &&
      cur_mode.dmDisplayFrequency <= 500u) {
    current_hz = static_cast<double>(cur_mode.dmDisplayFrequency);
    rates.insert(cur_mode.dmDisplayFrequency);
  }

  DEVMODEW mode = {};
  mode.dmSize = sizeof(DEVMODEW);
  for (DWORD idx = 0u;
       idx < 2048u && EnumDisplaySettingsW(device_name, idx, &mode); ++idx) {
    const bool same_res =
        cur_mode.dmPelsWidth == 0u ||
        (mode.dmPelsWidth == cur_mode.dmPelsWidth &&
         mode.dmPelsHeight == cur_mode.dmPelsHeight);
    if (same_res && mode.dmDisplayFrequency >= 48u &&
        mode.dmDisplayFrequency <= 500u) {
      rates.insert(mode.dmDisplayFrequency);
    }
    mode.dmSize = sizeof(DEVMODEW);
  }

  flutter::EncodableList supported;
  for (DWORD r : rates) {
    supported.push_back(flutter::EncodableValue(static_cast<double>(r)));
  }
  const double max_hz =
      rates.empty() ? current_hz : static_cast<double>(*rates.rbegin());

  flutter::EncodableMap info;
  info[flutter::EncodableValue("currentHz")] =
      flutter::EncodableValue(current_hz);
  info[flutter::EncodableValue("maxHz")] = flutter::EncodableValue(max_hz);
  info[flutter::EncodableValue("supportedHz")] =
      flutter::EncodableValue(supported);
  info[flutter::EncodableValue("enabled")] =
      flutter::EncodableValue(high_refresh_enabled_);
  return info;
}

void FlutterWindow::OnDestroy() {
  if (display_channel_) {
    display_channel_->SetMethodCallHandler(nullptr);
    display_channel_.reset();
  }
  if (timer_period_active_) {
    timeEndPeriod(1);
    timer_period_active_ = false;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugin, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
