#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

namespace {

constexpr auto kWindowThemeChannelName = "pkg_panel/window_theme";
constexpr auto kSetWindowThemeModeMethod = "setWindowThemeMode";
constexpr auto kThemeModeArgumentKey = "themeMode";
constexpr auto kLightBackgroundColorArgumentKey = "lightBackgroundColor";
constexpr auto kDarkBackgroundColorArgumentKey = "darkBackgroundColor";
constexpr auto kLightForegroundColorArgumentKey = "lightForegroundColor";
constexpr auto kDarkForegroundColorArgumentKey = "darkForegroundColor";

COLORREF ArgbToColorRef(uint32_t argb) {
  const auto red = static_cast<BYTE>((argb >> 16) & 0xFF);
  const auto green = static_cast<BYTE>((argb >> 8) & 0xFF);
  const auto blue = static_cast<BYTE>(argb & 0xFF);
  return RGB(red, green, blue);
}

std::optional<COLORREF> ReadColorRefArgument(
    const flutter::EncodableMap& arguments,
    const char* key) {
  const auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return std::nullopt;
  }

  const auto* color_value = std::get_if<int32_t>(&it->second);
  if (color_value != nullptr) {
    return ArgbToColorRef(static_cast<uint32_t>(*color_value));
  }

  const auto* long_color_value = std::get_if<int64_t>(&it->second);
  if (long_color_value != nullptr) {
    return ArgbToColorRef(static_cast<uint32_t>(*long_color_value));
  }

  return std::nullopt;
}

}  // namespace

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
  window_theme_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowThemeChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  window_theme_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() != kSetWindowThemeModeMethod) {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("bad_arguments", "Expected a themeMode map.");
          return;
        }

        const auto theme_mode_it =
            arguments->find(flutter::EncodableValue(kThemeModeArgumentKey));
        if (theme_mode_it == arguments->end()) {
          result->Error("bad_arguments", "Missing themeMode.");
          return;
        }

        const auto* theme_mode =
            std::get_if<std::string>(&theme_mode_it->second);
        if (theme_mode == nullptr) {
          result->Error("bad_arguments", "themeMode must be a string.");
          return;
        }

        const auto light_background_color = ReadColorRefArgument(
            *arguments, kLightBackgroundColorArgumentKey);
        const auto dark_background_color =
            ReadColorRefArgument(*arguments, kDarkBackgroundColorArgumentKey);
        const auto light_foreground_color = ReadColorRefArgument(
            *arguments, kLightForegroundColorArgumentKey);
        const auto dark_foreground_color =
            ReadColorRefArgument(*arguments, kDarkForegroundColorArgumentKey);

        if (*theme_mode == "system") {
          SetTitleBarColors(light_background_color, dark_background_color,
                            light_foreground_color, dark_foreground_color);
          SetThemeMode(std::nullopt);
          result->Success();
          return;
        }
        if (*theme_mode == "dark") {
          SetTitleBarColors(light_background_color, dark_background_color,
                            light_foreground_color, dark_foreground_color);
          SetThemeMode(true);
          result->Success();
          return;
        }
        if (*theme_mode == "light") {
          SetTitleBarColors(light_background_color, dark_background_color,
                            light_foreground_color, dark_foreground_color);
          SetThemeMode(false);
          result->Success();
          return;
        }

        result->Error("bad_arguments", "Unsupported themeMode.");
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_theme_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
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
