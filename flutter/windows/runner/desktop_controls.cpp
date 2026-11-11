#include "desktop_controls.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>

namespace {

class DesktopControls : public flutter::Plugin {
 public:
  explicit DesktopControls(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        channel_(registrar->messenger(), "org.rustdesk.rustdesk/desktop_controls",
                 &flutter::StandardMethodCodec::GetInstance()) {
    channel_.SetMethodCallHandler([this](const auto& call, auto result) {
      const auto view = registrar_->GetView();
      const HWND window = view ? GetAncestor(view->GetNativeWindow(), GA_ROOT) : nullptr;
      if (!window) {
        result->Error("no_window", "The Flutter window is unavailable");
      } else if (call.method_name() == "isAlwaysOnTop") {
        result->Success(flutter::EncodableValue(
            (GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0));
      } else if (call.method_name() == "setAlwaysOnTop") {
        const auto value = call.arguments()
            ? std::get_if<bool>(call.arguments()) : nullptr;
        if (!value || !SetWindowPos(window, *value ? HWND_TOPMOST : HWND_NOTOPMOST,
                                   0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)) {
          result->Error("set_topmost_failed", "Cannot change the window order");
        } else {
          result->Success();
        }
      } else if (call.method_name() == "enableRelativeMouse") {
        // Raw mouse registration is process-wide. Only the foreground window may own it.
        if (GetForegroundWindow() != window ||
            (active_ && active_ != this)) {
          result->Success(flutter::EncodableValue(false));
          return;
        }
        RAWINPUTDEVICE device{0x01, 0x02, 0, window};
        if (!RegisterRawInputDevices(&device, 1, sizeof(device))) {
          result->Success(flutter::EncodableValue(false));
          return;
        }
        active_ = this;
        center_x_ = center_y_ = -1;
        ReadCenter(call.arguments());
        if (!LockCenter()) {
          Disable();
          result->Success(flutter::EncodableValue(false));
          return;
        }
        result->Success(flutter::EncodableValue(true));
      } else if (call.method_name() == "updateRelativeMouseCenter") {
        ReadCenter(call.arguments());
        if (active_ == this && !LockCenter()) {
          Disable();
          channel_.InvokeMethod("relativeMouseStopped", nullptr);
        }
        result->Success();
      } else if (call.method_name() == "disableRelativeMouse") {
        Disable();
        result->Success();
      } else {
        result->NotImplemented();
      }
    });
    delegate_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam)
            -> std::optional<LRESULT> {
          if (active_ != this) return std::nullopt;
          if ((message == WM_ACTIVATE && LOWORD(wparam) == WA_INACTIVE) ||
              message == WM_DESTROY || message == WM_ENTERSIZEMOVE) {
            Disable();
            channel_.InvokeMethod("relativeMouseStopped", nullptr);
          } else if (message == WM_WINDOWPOSCHANGED || message == WM_SIZE) {
            if (!LockCenter()) {
              Disable();
              channel_.InvokeMethod("relativeMouseStopped", nullptr);
            }
          } else if (message == WM_INPUT) {
            RAWINPUT input{};
            UINT size = sizeof(input);
            const UINT read = GetRawInputData(reinterpret_cast<HRAWINPUT>(lparam),
                RID_INPUT, &input, &size, sizeof(RAWINPUTHEADER));
            if (read == static_cast<UINT>(-1)) {
              Disable();
              channel_.InvokeMethod("relativeMouseStopped", nullptr);
            } else if (input.header.dwType == RIM_TYPEMOUSE &&
                       !(input.data.mouse.usFlags & MOUSE_MOVE_ABSOLUTE) &&
                       (input.data.mouse.lLastX || input.data.mouse.lLastY)) {
              channel_.InvokeMethod("mouseDelta",
                  std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                      {flutter::EncodableValue("dx"), flutter::EncodableValue(
                          static_cast<int>(input.data.mouse.lLastX))},
                      {flutter::EncodableValue("dy"), flutter::EncodableValue(
                          static_cast<int>(input.data.mouse.lLastY))}}));
            }
            // Foreground WM_INPUT must reach DefWindowProc for system cleanup.
          }
          return std::nullopt;
        });
  }

  ~DesktopControls() override {
    Disable();
    channel_.SetMethodCallHandler(nullptr);
    registrar_->UnregisterTopLevelWindowProcDelegate(delegate_);
  }

 private:
  void ReadCenter(const flutter::EncodableValue* arguments) {
    const auto args = arguments ? std::get_if<flutter::EncodableMap>(arguments) : nullptr;
    if (!args) return;
    const auto x = args->find(flutter::EncodableValue("x"));
    const auto y = args->find(flutter::EncodableValue("y"));
    if (x != args->end() && y != args->end()) {
      const auto dx = std::get_if<double>(&x->second);
      const auto dy = std::get_if<double>(&y->second);
      if (dx && dy) {
        center_x_ = *dx;
        center_y_ = *dy;
      }
    }
  }

  bool LockCenter() {
    const auto view = registrar_->GetView();
    if (!view) return false;
    const HWND child = view->GetNativeWindow();
    RECT rect{};
    if (!GetClientRect(child, &rect) || rect.right <= 0 || rect.bottom <= 0) return false;
    const double scale = GetDpiForWindow(child) / 96.0;
    POINT center{center_x_ >= 0 ? static_cast<LONG>(center_x_ * scale) : rect.right / 2,
                 center_y_ >= 0 ? static_cast<LONG>(center_y_ * scale) : rect.bottom / 2};
    if (!ClientToScreen(child, &center)) return false;
    RECT clip{center.x, center.y, center.x + 1, center.y + 1};
    return ClipCursor(&clip) != FALSE;
  }

  void Disable() {
    if (active_ != this) return;
    active_ = nullptr;
    if (!ClipCursor(nullptr)) {
      OutputDebugStringA("rustdesk: failed to release the relative mouse cursor\n");
    }
    RAWINPUTDEVICE device{0x01, 0x02, RIDEV_REMOVE, nullptr};
    if (!RegisterRawInputDevices(&device, 1, sizeof(device))) {
      OutputDebugStringA("rustdesk: failed to unregister relative mouse input\n");
    }
  }

  static DesktopControls* active_;
  flutter::PluginRegistrarWindows* registrar_;
  flutter::MethodChannel<> channel_;
  int delegate_ = 0;
  double center_x_ = -1;
  double center_y_ = -1;
};

DesktopControls* DesktopControls::active_ = nullptr;

}  // namespace

void RegisterDesktopControls(flutter::PluginRegistry* registry) {
  auto registrar = flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(
          registry->GetRegistrarForPlugin("RustDeskDesktopControls"));
  registrar->AddPlugin(std::make_unique<DesktopControls>(registrar));
}
