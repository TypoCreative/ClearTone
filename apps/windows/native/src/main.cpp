#include "audio_engine.h"

#include <Windows.h>
#include <commctrl.h>
#include <dwmapi.h>
#include <psapi.h>
#include <shellapi.h>

#include <algorithm>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace {
constexpr wchar_t kWindowClass[] = L"ClearToneWindow";
constexpr UINT kStatusMessage = WM_APP + 1;
constexpr UINT kTrayMessage = WM_APP + 2;
constexpr UINT_PTR kMetricsTimer = 1;
constexpr int kStartButton = 1001;
constexpr int kStrengthSlider = 1002;
constexpr int kOutputPicker = 1003;
constexpr int kTrayOpen = 2001;
constexpr int kTrayExit = 2002;

struct AppState {
  AudioEngine engine;
  HWND startButton = nullptr;
  HWND statusText = nullptr;
  HWND metricsText = nullptr;
  HWND performanceText = nullptr;
  HWND strengthSlider = nullptr;
  HWND outputPicker = nullptr;
  std::vector<AudioEngine::Device> outputDevices;
  HFONT titleFont = nullptr;
  HFONT bodyFont = nullptr;
  HBRUSH background = nullptr;
  NOTIFYICONDATAW tray{};
  std::wstring status = L"Ready";
  ULONGLONG previousProcessTime = 0;
  ULONGLONG previousWallTime = 0;
};

ULONGLONG fileTimeValue(const FILETIME& value) {
  ULARGE_INTEGER result{};
  result.LowPart = value.dwLowDateTime;
  result.HighPart = value.dwHighDateTime;
  return result.QuadPart;
}

void updatePerformance(AppState& state) {
  PROCESS_MEMORY_COUNTERS_EX memory{};
  memory.cb = sizeof(memory);
  const BOOL hasMemory = GetProcessMemoryInfo(
      GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory), sizeof(memory));

  FILETIME created{}, exited{}, kernel{}, user{};
  FILETIME wall{};
  GetSystemTimeAsFileTime(&wall);
  const BOOL hasTimes = GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user);
  const ULONGLONG wallTime = fileTimeValue(wall);
  const ULONGLONG processTime = hasTimes ? fileTimeValue(kernel) + fileTimeValue(user) : 0;

  float cpu = 0.0F;
  if (state.previousWallTime > 0 && wallTime > state.previousWallTime &&
      processTime >= state.previousProcessTime) {
    SYSTEM_INFO system{};
    GetSystemInfo(&system);
    const auto processors = std::max<DWORD>(system.dwNumberOfProcessors, 1);
    cpu = static_cast<float>(processTime - state.previousProcessTime) * 100.0F /
          static_cast<float>(wallTime - state.previousWallTime) /
          static_cast<float>(processors);
  }
  state.previousWallTime = wallTime;
  state.previousProcessTime = processTime;

  wchar_t text[192]{};
  const double memoryMB = hasMemory
      ? static_cast<double>(memory.PrivateUsage) / (1024.0 * 1024.0)
      : 0.0;
  swprintf_s(text, L"CPU %.1f%%   Memory %.1f MB   GPU not used",
             std::clamp(cpu, 0.0F, 100.0F), memoryMB);
  SetWindowTextW(state.performanceText, text);
}

void setControlFont(HWND control, HFONT font) {
  SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);
}

HWND addText(HWND parent, const wchar_t* text, int x, int y, int width, int height, HFONT font) {
  HWND control = CreateWindowExW(0, L"STATIC", text, WS_CHILD | WS_VISIBLE,
                                 x, y, width, height, parent, nullptr, nullptr, nullptr);
  setControlFont(control, font);
  return control;
}

void updateButton(AppState& state) {
  SetWindowTextW(state.startButton, state.engine.isRunning() ? L"Stop processing" : L"Start processing");
  if (state.outputPicker) EnableWindow(state.outputPicker, !state.engine.isRunning());
}

void addTrayIcon(HWND window, AppState& state) {
  state.tray.cbSize = sizeof(state.tray);
  state.tray.hWnd = window;
  state.tray.uID = 1;
  state.tray.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  state.tray.uCallbackMessage = kTrayMessage;
  state.tray.hIcon = static_cast<HICON>(LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(101),
                                                   IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR));
  wcscpy_s(state.tray.szTip, L"ClearTone");
  Shell_NotifyIconW(NIM_ADD, &state.tray);
  state.tray.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &state.tray);
}

void showTrayMenu(HWND window) {
  POINT cursor{};
  GetCursorPos(&cursor);
  HMENU menu = CreatePopupMenu();
  AppendMenuW(menu, MF_STRING, kTrayOpen, L"Open ClearTone");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kTrayExit, L"Exit");
  SetForegroundWindow(window);
  TrackPopupMenu(menu, TPM_RIGHTALIGN | TPM_BOTTOMALIGN, cursor.x, cursor.y, 0, window, nullptr);
  DestroyMenu(menu);
}

LRESULT CALLBACK windowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
  auto* state = reinterpret_cast<AppState*>(GetWindowLongPtrW(window, GWLP_USERDATA));
  switch (message) {
    case WM_CREATE: {
      auto* create = reinterpret_cast<CREATESTRUCTW*>(lParam);
      state = reinterpret_cast<AppState*>(create->lpCreateParams);
      SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(state));

      const BOOL darkMode = TRUE;
      DwmSetWindowAttribute(window, 20, &darkMode, sizeof(darkMode));
      const int backdrop = 2; // DWMSBT_MAINWINDOW on Windows 11; ignored elsewhere.
      DwmSetWindowAttribute(window, 38, &backdrop, sizeof(backdrop));

      state->titleFont = CreateFontW(30, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                                     DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                     CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI Variable Display");
      state->bodyFont = CreateFontW(17, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                    CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI Variable Text");
      state->background = CreateSolidBrush(RGB(20, 23, 30));

      addText(window, L"ClearTone", 32, 25, 320, 45, state->titleFont);
      addText(window, L"Private, real-time voice clarity on Windows", 34, 69, 520, 28, state->bodyFont);
      addText(window, L"AUDIO ROUTING", 34, 118, 240, 24, state->bodyFont);
      addText(window, L"Default microphone   →   Voice Engine   →   Selected output", 34, 148, 620, 34, state->bodyFont);
      addText(window, L"Choose a virtual-cable playback endpoint when cleaned audio must appear as a microphone.",
              34, 181, 650, 36, state->bodyFont);

      addText(window, L"Output", 34, 230, 180, 28, state->bodyFont);
      state->outputPicker = CreateWindowExW(0, L"COMBOBOX", nullptr,
          WS_CHILD | WS_VISIBLE | WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL,
          250, 225, 390, 240, window, reinterpret_cast<HMENU>(kOutputPicker), nullptr, nullptr);
      setControlFont(state->outputPicker, state->bodyFont);
      state->outputDevices = AudioEngine::outputDevices();
      for (const auto& device : state->outputDevices) {
        SendMessageW(state->outputPicker, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(device.name.c_str()));
      }
      if (!state->outputDevices.empty()) SendMessageW(state->outputPicker, CB_SETCURSEL, 0, 0);

      addText(window, L"Noise reduction", 34, 284, 220, 28, state->bodyFont);
      state->strengthSlider = CreateWindowExW(0, TRACKBAR_CLASSW, nullptr,
          WS_CHILD | WS_VISIBLE | TBS_AUTOTICKS, 250, 279, 390, 34, window,
          reinterpret_cast<HMENU>(kStrengthSlider), nullptr, nullptr);
      SendMessageW(state->strengthSlider, TBM_SETRANGE, TRUE, MAKELPARAM(0, 100));
      SendMessageW(state->strengthSlider, TBM_SETPOS, TRUE, 82);
      SetWindowTextW(state->strengthSlider, L"Noise reduction strength");

      state->startButton = CreateWindowExW(0, L"BUTTON", L"Start processing",
          WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON, 34, 338, 190, 42, window,
          reinterpret_cast<HMENU>(kStartButton), nullptr, nullptr);
      setControlFont(state->startButton, state->bodyFont);
      state->statusText = addText(window, L"Ready", 246, 346, 430, 30, state->bodyFont);
      addText(window, L"LIVE METRICS", 34, 416, 220, 24, state->bodyFont);
      state->metricsText = addText(window, L"Input 0%   Output 0%   Voice 0%   Frames 0   Drops 0",
                                   34, 448, 640, 34, state->bodyFont);
      addText(window, L"PERFORMANCE", 34, 489, 220, 24, state->bodyFont);
      state->performanceText = addText(window, L"CPU 0.0%   Memory 0.0 MB   GPU not used",
                                       34, 519, 640, 30, state->bodyFont);

      addTrayIcon(window, *state);
      SetTimer(window, kMetricsTimer, 500, nullptr);
      return 0;
    }
    case WM_COMMAND:
      if (state && LOWORD(wParam) == kStartButton) {
        if (state->engine.isRunning()) {
          state->engine.stop();
          state->status = L"Ready";
          SetWindowTextW(state->statusText, state->status.c_str());
        } else {
          SetWindowTextW(state->statusText, L"Starting…");
          const LRESULT selected = SendMessageW(state->outputPicker, CB_GETCURSEL, 0, 0);
          std::wstring outputId;
          if (selected != CB_ERR && static_cast<size_t>(selected) < state->outputDevices.size()) {
            outputId = state->outputDevices[static_cast<size_t>(selected)].id;
          }
          state->engine.start([window](const std::wstring& status) {
            auto* copy = new std::wstring(status);
            if (!PostMessageW(window, kStatusMessage, 0, reinterpret_cast<LPARAM>(copy))) delete copy;
          }, std::move(outputId));
        }
        updateButton(*state);
        return 0;
      }
      if (LOWORD(wParam) == kTrayOpen) {
        ShowWindow(window, SW_SHOW);
        SetForegroundWindow(window);
        return 0;
      }
      if (LOWORD(wParam) == kTrayExit) {
        DestroyWindow(window);
        return 0;
      }
      break;
    case WM_HSCROLL:
      if (state && reinterpret_cast<HWND>(lParam) == state->strengthSlider) {
        const auto value = static_cast<float>(SendMessageW(state->strengthSlider, TBM_GETPOS, 0, 0));
        state->engine.setStrength(value / 100.0F);
      }
      return 0;
    case kStatusMessage:
      if (state) {
        std::unique_ptr<std::wstring> status(reinterpret_cast<std::wstring*>(lParam));
        state->status = *status;
        SetWindowTextW(state->statusText, state->status.c_str());
        updateButton(*state);
      }
      return 0;
    case WM_TIMER:
      if (state && wParam == kMetricsTimer) {
        const auto metrics = state->engine.metrics();
        wchar_t text[256]{};
        swprintf_s(text, L"Input %.0f%%   Output %.0f%%   Voice %.0f%%   Frames %llu   Drops %llu",
                   std::clamp(metrics.inputLevel * 100.0F, 0.0F, 100.0F),
                   std::clamp(metrics.outputLevel * 100.0F, 0.0F, 100.0F),
                   std::clamp(metrics.voiceProbability * 100.0F, 0.0F, 100.0F),
                   metrics.processedFrames, metrics.droppedFrames);
        SetWindowTextW(state->metricsText, text);
        updatePerformance(*state);
        updateButton(*state);
      }
      return 0;
    case kTrayMessage:
      if (LOWORD(lParam) == WM_LBUTTONUP) {
        ShowWindow(window, IsWindowVisible(window) ? SW_HIDE : SW_SHOW);
      } else if (LOWORD(lParam) == WM_CONTEXTMENU || LOWORD(lParam) == WM_RBUTTONUP) {
        showTrayMenu(window);
      }
      return 0;
    case WM_CLOSE:
      ShowWindow(window, SW_HIDE);
      return 0;
    case WM_CTLCOLORSTATIC:
      SetTextColor(reinterpret_cast<HDC>(wParam), RGB(232, 236, 245));
      SetBkMode(reinterpret_cast<HDC>(wParam), TRANSPARENT);
      return reinterpret_cast<INT_PTR>(state ? state->background : nullptr);
    case WM_ERASEBKGND:
      if (state && state->background) {
        RECT bounds{};
        GetClientRect(window, &bounds);
        FillRect(reinterpret_cast<HDC>(wParam), &bounds, state->background);
        return 1;
      }
      break;
    case WM_DESTROY:
      if (state) {
        KillTimer(window, kMetricsTimer);
        state->engine.stop();
        Shell_NotifyIconW(NIM_DELETE, &state->tray);
        if (state->tray.hIcon) DestroyIcon(state->tray.hIcon);
        if (state->titleFont) DeleteObject(state->titleFont);
        if (state->bodyFont) DeleteObject(state->bodyFont);
        if (state->background) DeleteObject(state->background);
      }
      PostQuitMessage(0);
      return 0;
  }
  return DefWindowProcW(window, message, wParam, lParam);
}
} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int showCommand) {
  HANDLE instanceMutex = CreateMutexW(nullptr, TRUE, L"Local\\TypoCreative.ClearTone");
  if (instanceMutex && GetLastError() == ERROR_ALREADY_EXISTS) {
    if (HWND existing = FindWindowW(kWindowClass, nullptr)) {
      ShowWindow(existing, SW_SHOW);
      SetForegroundWindow(existing);
    }
    CloseHandle(instanceMutex);
    return 0;
  }

  INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_BAR_CLASSES | ICC_STANDARD_CLASSES};
  InitCommonControlsEx(&controls);
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

  WNDCLASSEXW windowClass{sizeof(windowClass)};
  windowClass.style = CS_HREDRAW | CS_VREDRAW;
  windowClass.lpfnWndProc = windowProcedure;
  windowClass.hInstance = instance;
  windowClass.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(101));
  windowClass.hIconSm = LoadIconW(instance, MAKEINTRESOURCEW(101));
  windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  windowClass.lpszClassName = kWindowClass;
  if (!RegisterClassExW(&windowClass)) {
    if (instanceMutex) CloseHandle(instanceMutex);
    return 1;
  }

  AppState state;
  HWND window = CreateWindowExW(0, kWindowClass, L"ClearTone",
      WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
      CW_USEDEFAULT, CW_USEDEFAULT, 740, 635, nullptr, nullptr, instance, &state);
  if (!window) {
    if (instanceMutex) CloseHandle(instanceMutex);
    return 1;
  }
  ShowWindow(window, showCommand);
  UpdateWindow(window);

  MSG message{};
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  if (instanceMutex) CloseHandle(instanceMutex);
  return static_cast<int>(message.wParam);
}
