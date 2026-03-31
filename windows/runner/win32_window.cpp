#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include <filesystem>
#include <fstream>
#include <optional>
#include <string>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif

constexpr COLORREF kDwmDefaultColor = 0xFFFFFFFF;

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

constexpr const wchar_t kSettingsDirectoryName[] = L"pkg_panel";
constexpr const wchar_t kManagerSettingsFileName[] = L"manager_settings.json";
constexpr const wchar_t kWindowStateFileName[] = L"window_state.txt";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

std::wstring ReadEnvironmentVariable(const wchar_t* key) {
  const DWORD required_size = GetEnvironmentVariableW(key, nullptr, 0);
  if (required_size == 0) {
    return L"";
  }

  std::wstring value(required_size - 1, L'\0');
  const DWORD actual_size =
      GetEnvironmentVariableW(key, value.data(), required_size);
  if (actual_size == 0) {
    return L"";
  }
  return value;
}

std::filesystem::path ResolveSettingsDirectoryPath() {
  for (const auto* key : {L"LOCALAPPDATA", L"APPDATA"}) {
    const std::wstring value = ReadEnvironmentVariable(key);
    if (!value.empty()) {
      return std::filesystem::path(value) / kSettingsDirectoryName;
    }
  }
  return std::filesystem::temp_directory_path() / kSettingsDirectoryName;
}

std::filesystem::path ResolveSettingsFilePath(const wchar_t* file_name) {
  return ResolveSettingsDirectoryPath() / file_name;
}

std::optional<std::string> ReadTextFile(
    const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::in);
  if (!stream.is_open()) {
    return std::nullopt;
  }
  return std::string((std::istreambuf_iterator<char>(stream)),
                     std::istreambuf_iterator<char>());
}

std::optional<int> ParseIntSetting(const std::string& content,
                                   const std::string& key) {
  const std::string prefix = key + "=";
  const size_t start = content.find(prefix);
  if (start == std::string::npos) {
    return std::nullopt;
  }

  size_t value_start = start + prefix.size();
  size_t value_end = content.find_first_of("\r\n", value_start);
  const std::string value = content.substr(value_start, value_end - value_start);
  if (value.empty()) {
    return std::nullopt;
  }

  try {
    return std::stoi(value);
  } catch (...) {
    return std::nullopt;
  }
}

bool ParseBoolFromJsonSetting(const std::string& content,
                              const std::string& key,
                              bool fallback) {
  const std::string needle = "\"" + key + "\"";
  const size_t key_index = content.find(needle);
  if (key_index == std::string::npos) {
    return fallback;
  }

  size_t value_index = content.find(':', key_index + needle.size());
  if (value_index == std::string::npos) {
    return fallback;
  }
  value_index += 1;
  while (value_index < content.size() &&
         (content[value_index] == ' ' || content[value_index] == '\t' ||
          content[value_index] == '\r' || content[value_index] == '\n')) {
    value_index += 1;
  }
  if (content.compare(value_index, 4, "true") == 0) {
    return true;
  }
  if (content.compare(value_index, 5, "false") == 0) {
    return false;
  }
  return fallback;
}

bool IsPlacementVisible(const RECT& rect) {
  return MonitorFromRect(&rect, MONITOR_DEFAULTTONULL) != nullptr;
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size,
                         bool coordinates_are_physical) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  int window_x = origin.x;
  int window_y = origin.y;
  int window_width = static_cast<int>(size.width);
  int window_height = static_cast<int>(size.height);

  if (!coordinates_are_physical) {
    const POINT target_point = {static_cast<LONG>(origin.x),
                                static_cast<LONG>(origin.y)};
    HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
    UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    double scale_factor = dpi / 96.0;
    window_x = Scale(origin.x, scale_factor);
    window_y = Scale(origin.y, scale_factor);
    window_width = Scale(static_cast<int>(size.width), scale_factor);
    window_height = Scale(static_cast<int>(size.height), scale_factor);
  }

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW, window_x, window_y,
      window_width, window_height, nullptr, nullptr, GetModuleHandle(nullptr),
      this);

  if (!window) {
    return false;
  }

  UpdateTheme();

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, initial_show_state_);
}

void Win32Window::SetInitialShowState(int show_state) {
  initial_show_state_ =
      show_state == SW_SHOWMAXIMIZED ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
}

void Win32Window::SetMinimumSize(Size size) {
  minimum_size_ = size;
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      SaveWindowPlacement(hwnd);
      break;

    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_GETMINMAXINFO: {
      if (!minimum_size_.has_value()) {
        break;
      }

      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const HMONITOR monitor =
          MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
      const double scale_factor = dpi / 96.0;
      info->ptMinTrackSize.x =
          Scale(static_cast<int>(minimum_size_->width), scale_factor);
      info->ptMinTrackSize.y =
          Scale(static_cast<int>(minimum_size_->height), scale_factor);
      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_SETTINGCHANGE:
    case WM_THEMECHANGED:
    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme();
      break;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  if (window_handle_) {
    SaveWindowPlacement(window_handle_);
  }
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

std::optional<Win32Window::SavedWindowPlacement>
Win32Window::LoadSavedWindowPlacement() {
  if (!ShouldRememberWindowPlacement()) {
    return std::nullopt;
  }

  const auto content = ReadTextFile(ResolveSettingsFilePath(kWindowStateFileName));
  if (!content.has_value()) {
    return std::nullopt;
  }

  const auto left = ParseIntSetting(*content, "left");
  const auto top = ParseIntSetting(*content, "top");
  const auto width = ParseIntSetting(*content, "width");
  const auto height = ParseIntSetting(*content, "height");
  const auto maximized = ParseIntSetting(*content, "maximized");
  if (!left.has_value() || !top.has_value() || !width.has_value() ||
      !height.has_value() || !maximized.has_value()) {
    return std::nullopt;
  }
  if (*width < 320 || *height < 240) {
    return std::nullopt;
  }

  RECT bounds{*left, *top, *left + *width, *top + *height};
  if (!IsPlacementVisible(bounds)) {
    return std::nullopt;
  }

  return SavedWindowPlacement(
      Point(*left, *top), Size(static_cast<unsigned int>(*width),
                               static_cast<unsigned int>(*height)),
      *maximized != 0);
}

void Win32Window::SetThemeMode(std::optional<bool> prefers_dark_mode) {
  prefers_dark_mode_ = prefers_dark_mode;
  UpdateTheme();
}

void Win32Window::SetTitleBarColors(
    std::optional<COLORREF> light_background_color,
    std::optional<COLORREF> dark_background_color,
    std::optional<COLORREF> light_foreground_color,
    std::optional<COLORREF> dark_foreground_color) {
  light_title_bar_background_color_ = light_background_color;
  dark_title_bar_background_color_ = dark_background_color;
  light_title_bar_foreground_color_ = light_foreground_color;
  dark_title_bar_foreground_color_ = dark_foreground_color;
  UpdateTheme();
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

bool Win32Window::IsSystemDarkModeEnabled() {
  DWORD light_mode = 1;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  return result == ERROR_SUCCESS && light_mode == 0;
}

bool Win32Window::ShouldRememberWindowPlacement() {
  const auto content =
      ReadTextFile(ResolveSettingsFilePath(kManagerSettingsFileName));
  if (!content.has_value()) {
    return true;
  }
  return ParseBoolFromJsonSetting(*content, "rememberWindowPlacement", true);
}

void Win32Window::SaveWindowPlacement(HWND window) {
  if (window == nullptr || !ShouldRememberWindowPlacement()) {
    return;
  }

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(WINDOWPLACEMENT);
  if (!GetWindowPlacement(window, &placement)) {
    return;
  }

  const bool maximized = IsZoomed(window) || placement.showCmd == SW_SHOWMAXIMIZED;
  const RECT bounds = placement.rcNormalPosition;
  const int width = bounds.right - bounds.left;
  const int height = bounds.bottom - bounds.top;
  if (width < 320 || height < 240) {
    return;
  }

  const auto path = ResolveSettingsFilePath(kWindowStateFileName);
  std::error_code error;
  std::filesystem::create_directories(path.parent_path(), error);

  std::ofstream stream(path, std::ios::out | std::ios::trunc);
  if (!stream.is_open()) {
    return;
  }

  stream << "left=" << bounds.left << '\n'
         << "top=" << bounds.top << '\n'
         << "width=" << width << '\n'
         << "height=" << height << '\n'
         << "maximized=" << (maximized ? 1 : 0) << '\n';
}

void Win32Window::ApplyTheme(HWND window, bool enable_dark_mode,
                             std::optional<COLORREF> caption_color,
                             std::optional<COLORREF> text_color) {
  BOOL use_dark_mode = enable_dark_mode ? TRUE : FALSE;
  DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &use_dark_mode,
                        sizeof(use_dark_mode));

  const COLORREF title_bar_color =
      caption_color.has_value() ? *caption_color : kDwmDefaultColor;
  DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &title_bar_color,
                        sizeof(title_bar_color));

  const COLORREF title_bar_text_color =
      text_color.has_value() ? *text_color : kDwmDefaultColor;
  DwmSetWindowAttribute(window, DWMWA_TEXT_COLOR, &title_bar_text_color,
                        sizeof(title_bar_text_color));

  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
}

void Win32Window::UpdateTheme() {
  if (!window_handle_) {
    return;
  }

  const bool use_dark_mode = prefers_dark_mode_.has_value()
                                 ? *prefers_dark_mode_
                                 : IsSystemDarkModeEnabled();

  ApplyTheme(window_handle_, use_dark_mode,
             use_dark_mode ? dark_title_bar_background_color_
                           : light_title_bar_background_color_,
             use_dark_mode ? dark_title_bar_foreground_color_
                           : light_title_bar_foreground_color_);
}
