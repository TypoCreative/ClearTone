#include "audio_engine.h"

#include <Windows.h>
#include <audioclient.h>
#include <avrt.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mmdeviceapi.h>
#include <propvarutil.h>
#include <wrl/client.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <deque>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

extern "C" {
#include "rnnoise.h"
}

using Microsoft::WRL::ComPtr;

namespace {
constexpr UINT32 kSampleRate = 48000;
constexpr UINT32 kFrameSize = 480;
constexpr REFERENCE_TIME kBufferDuration = 200000; // 20 ms in 100 ns units.

WAVEFORMATEX processingFormat() {
  WAVEFORMATEX format{};
  format.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
  format.nChannels = 1;
  format.nSamplesPerSec = kSampleRate;
  format.wBitsPerSample = 32;
  format.nBlockAlign = static_cast<WORD>(format.nChannels * format.wBitsPerSample / 8);
  format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;
  return format;
}

std::wstring hresultMessage(const wchar_t* operation, HRESULT result) {
  wchar_t code[24]{};
  swprintf_s(code, L"0x%08X", static_cast<unsigned int>(result));
  return std::wstring(operation) + L" failed (" + code + L")";
}

float rms(const float* samples, size_t count) {
  if (count == 0) return 0.0F;
  double sum = 0.0;
  for (size_t index = 0; index < count; ++index) {
    const double sample = samples[index];
    sum += sample * sample;
  }
  return static_cast<float>(std::sqrt(sum / static_cast<double>(count)));
}
} // namespace

struct AudioEngine::Impl {
  std::atomic_bool running{false};
  std::atomic_bool stopRequested{false};
  std::atomic<float> strength{0.82F};
  std::atomic<float> inputLevel{0.0F};
  std::atomic<float> outputLevel{0.0F};
  std::atomic<float> voiceProbability{0.0F};
  std::atomic<unsigned long long> processedFrames{0};
  std::atomic<unsigned long long> droppedFrames{0};
  std::thread worker;
  StatusCallback callback;
  std::wstring outputDeviceId;

  void report(const std::wstring& message) const {
    if (callback) callback(message);
  }

  void run() {
    const HRESULT comResult = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (FAILED(comResult)) {
      report(hresultMessage(L"COM initialization", comResult));
      running = false;
      return;
    }

    DWORD taskIndex = 0;
    HANDLE mmcss = AvSetMmThreadCharacteristicsW(L"Audio", &taskIndex);
    ComPtr<IMMDeviceEnumerator> enumerator;
    ComPtr<IMMDevice> inputDevice;
    ComPtr<IMMDevice> outputDevice;
    ComPtr<IAudioClient> captureClient;
    ComPtr<IAudioClient> renderClient;
    ComPtr<IAudioCaptureClient> capture;
    ComPtr<IAudioRenderClient> render;
    HANDLE captureEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    HANDLE renderEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    HRESULT result = S_OK;

    auto fail = [&](const wchar_t* operation, HRESULT value) {
      report(hresultMessage(operation, value));
      result = value;
    };

    result = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(&enumerator));
    if (FAILED(result)) fail(L"Audio device discovery", result);
    if (SUCCEEDED(result)) {
      result = enumerator->GetDefaultAudioEndpoint(eCapture, eCommunications, &inputDevice);
      if (FAILED(result)) {
        result = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &inputDevice);
      }
      if (FAILED(result)) fail(L"Default microphone", result);
    }
    if (SUCCEEDED(result)) {
      if (outputDeviceId.empty()) {
        result = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &outputDevice);
      } else {
        result = enumerator->GetDevice(outputDeviceId.c_str(), &outputDevice);
      }
      if (FAILED(result)) fail(L"Selected output", result);
    }
    if (SUCCEEDED(result)) {
      result = inputDevice->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, &captureClient);
      if (FAILED(result)) fail(L"Microphone activation", result);
    }
    if (SUCCEEDED(result)) {
      result = outputDevice->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, &renderClient);
      if (FAILED(result)) fail(L"Output activation", result);
    }

    WAVEFORMATEX format = processingFormat();
    constexpr DWORD flags = AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                            AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                            AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
    if (SUCCEEDED(result)) {
      result = captureClient->Initialize(AUDCLNT_SHAREMODE_SHARED, flags, kBufferDuration, 0,
                                         &format, nullptr);
      if (FAILED(result)) fail(L"Microphone format setup", result);
    }
    if (SUCCEEDED(result)) {
      result = renderClient->Initialize(AUDCLNT_SHAREMODE_SHARED, flags, kBufferDuration, 0,
                                        &format, nullptr);
      if (FAILED(result)) fail(L"Output format setup", result);
    }
    if (SUCCEEDED(result) && (!captureEvent || !renderEvent)) {
      fail(L"Audio event creation", HRESULT_FROM_WIN32(GetLastError()));
    }
    if (SUCCEEDED(result)) result = captureClient->SetEventHandle(captureEvent);
    if (SUCCEEDED(result)) result = renderClient->SetEventHandle(renderEvent);
    if (FAILED(result)) fail(L"Audio event setup", result);
    if (SUCCEEDED(result)) result = captureClient->GetService(IID_PPV_ARGS(&capture));
    if (SUCCEEDED(result)) result = renderClient->GetService(IID_PPV_ARGS(&render));
    if (FAILED(result)) fail(L"Audio stream setup", result);

    DenoiseState* denoiser = nullptr;
    if (SUCCEEDED(result)) {
      denoiser = rnnoise_create(nullptr);
      if (!denoiser) fail(L"RNNoise initialization", E_OUTOFMEMORY);
    }

    UINT32 renderBufferFrames = 0;
    if (SUCCEEDED(result)) result = renderClient->GetBufferSize(&renderBufferFrames);
    if (SUCCEEDED(result)) result = renderClient->Start();
    if (SUCCEEDED(result)) result = captureClient->Start();
    if (FAILED(result)) fail(L"Audio start", result);

    std::deque<float> inputQueue;
    std::deque<float> outputQueue;
    std::array<float, kFrameSize> inputFrame{};
    std::array<float, kFrameSize> rnnoiseFrame{};
    std::array<float, kFrameSize> processedFrame{};

    if (SUCCEEDED(result)) {
      running = true;
      report(L"Processing default microphone to selected output");
    }

    HANDLE events[] = {captureEvent, renderEvent};
    while (SUCCEEDED(result) && !stopRequested.load()) {
      const DWORD waitResult = WaitForMultipleObjects(2, events, FALSE, 1000);
      if (waitResult == WAIT_OBJECT_0) {
        UINT32 packetFrames = 0;
        while (true) {
          result = capture->GetNextPacketSize(&packetFrames);
          if (FAILED(result)) {
            fail(L"Microphone packet query", result);
            break;
          }
          if (packetFrames == 0) break;
          BYTE* data = nullptr;
          DWORD packetFlags = 0;
          UINT32 frames = 0;
          result = capture->GetBuffer(&data, &frames, &packetFlags, nullptr, nullptr);
          if (FAILED(result)) {
            fail(L"Microphone read", result);
            break;
          }
          if ((packetFlags & AUDCLNT_BUFFERFLAGS_SILENT) != 0 || data == nullptr) {
            inputQueue.insert(inputQueue.end(), frames, 0.0F);
          } else {
            const auto* samples = reinterpret_cast<const float*>(data);
            inputQueue.insert(inputQueue.end(), samples, samples + frames);
          }
          capture->ReleaseBuffer(frames);
          if (inputQueue.size() > kSampleRate) {
            const size_t excess = inputQueue.size() - kSampleRate;
            inputQueue.erase(inputQueue.begin(), inputQueue.begin() + static_cast<ptrdiff_t>(excess));
            droppedFrames += excess;
          }
        }

        while (inputQueue.size() >= kFrameSize) {
          for (UINT32 index = 0; index < kFrameSize; ++index) {
            inputFrame[index] = inputQueue.front();
            inputQueue.pop_front();
            rnnoiseFrame[index] = std::clamp(inputFrame[index], -1.0F, 1.0F) * 32768.0F;
          }
          const float probability = rnnoise_process_frame(denoiser, rnnoiseFrame.data(), rnnoiseFrame.data());
          const float mix = std::clamp(strength.load(), 0.0F, 1.0F);
          for (UINT32 index = 0; index < kFrameSize; ++index) {
            const float cleaned = rnnoiseFrame[index] / 32768.0F;
            processedFrame[index] = std::clamp(inputFrame[index] * (1.0F - mix) + cleaned * mix,
                                               -1.0F, 1.0F);
            outputQueue.push_back(processedFrame[index]);
          }
          inputLevel = rms(inputFrame.data(), inputFrame.size());
          outputLevel = rms(processedFrame.data(), processedFrame.size());
          voiceProbability = probability;
          processedFrames++;
        }
      } else if (waitResult != WAIT_OBJECT_0 + 1 && waitResult != WAIT_TIMEOUT) {
        fail(L"Audio wait", HRESULT_FROM_WIN32(GetLastError()));
      }

      if (SUCCEEDED(result) && (waitResult == WAIT_OBJECT_0 + 1 || !outputQueue.empty())) {
        UINT32 padding = 0;
        result = renderClient->GetCurrentPadding(&padding);
        if (SUCCEEDED(result)) {
          const UINT32 available = renderBufferFrames > padding ? renderBufferFrames - padding : 0;
          if (available > 0) {
            BYTE* destination = nullptr;
            result = render->GetBuffer(available, &destination);
            if (SUCCEEDED(result)) {
              auto* samples = reinterpret_cast<float*>(destination);
              for (UINT32 index = 0; index < available; ++index) {
                if (outputQueue.empty()) {
                  samples[index] = 0.0F;
                } else {
                  samples[index] = outputQueue.front();
                  outputQueue.pop_front();
                }
              }
              result = render->ReleaseBuffer(available, 0);
            }
          }
        }
        if (FAILED(result)) fail(L"Output write", result);
      }
    }

    if (captureClient) captureClient->Stop();
    if (renderClient) renderClient->Stop();
    if (denoiser) rnnoise_destroy(denoiser);
    if (captureEvent) CloseHandle(captureEvent);
    if (renderEvent) CloseHandle(renderEvent);
    if (mmcss) AvRevertMmThreadCharacteristics(mmcss);
    running = false;
    CoUninitialize();
  }
};

AudioEngine::AudioEngine() : impl_(std::make_unique<Impl>()) {}
AudioEngine::~AudioEngine() { stop(); }

std::vector<AudioEngine::Device> AudioEngine::outputDevices() {
  std::vector<Device> devices{{L"", L"System default playback"}};
  const HRESULT comResult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool uninitialize = SUCCEEDED(comResult);
  if (FAILED(comResult) && comResult != RPC_E_CHANGED_MODE) return devices;

  ComPtr<IMMDeviceEnumerator> enumerator;
  ComPtr<IMMDeviceCollection> collection;
  HRESULT result = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                    IID_PPV_ARGS(&enumerator));
  if (SUCCEEDED(result)) {
    result = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
  }
  UINT count = 0;
  if (SUCCEEDED(result)) result = collection->GetCount(&count);
  for (UINT index = 0; SUCCEEDED(result) && index < count; ++index) {
    ComPtr<IMMDevice> device;
    ComPtr<IPropertyStore> properties;
    LPWSTR id = nullptr;
    PROPVARIANT name;
    PropVariantInit(&name);
    if (SUCCEEDED(collection->Item(index, &device)) &&
        SUCCEEDED(device->GetId(&id)) &&
        SUCCEEDED(device->OpenPropertyStore(STGM_READ, &properties)) &&
        SUCCEEDED(properties->GetValue(PKEY_Device_FriendlyName, &name)) &&
        name.vt == VT_LPWSTR && name.pwszVal) {
      devices.push_back({id, name.pwszVal});
    }
    CoTaskMemFree(id);
    PropVariantClear(&name);
  }
  if (uninitialize) CoUninitialize();
  return devices;
}

bool AudioEngine::start(StatusCallback callback, std::wstring outputDeviceId) {
  if (impl_->running) return false;
  if (impl_->worker.joinable()) impl_->worker.join();
  impl_->callback = std::move(callback);
  impl_->outputDeviceId = std::move(outputDeviceId);
  impl_->stopRequested = false;
  impl_->inputLevel = 0.0F;
  impl_->outputLevel = 0.0F;
  impl_->voiceProbability = 0.0F;
  impl_->processedFrames = 0;
  impl_->droppedFrames = 0;
  impl_->running = true;
  try {
    impl_->worker = std::thread([this] { impl_->run(); });
  } catch (...) {
    impl_->running = false;
    impl_->report(L"Unable to start the audio worker");
    return false;
  }
  return true;
}

void AudioEngine::stop() {
  impl_->stopRequested = true;
  if (impl_->worker.joinable()) impl_->worker.join();
}

bool AudioEngine::isRunning() const noexcept { return impl_->running.load(); }

void AudioEngine::setStrength(float value) noexcept {
  impl_->strength = std::clamp(value, 0.0F, 1.0F);
}

AudioEngine::Metrics AudioEngine::metrics() const noexcept {
  return {impl_->inputLevel.load(), impl_->outputLevel.load(), impl_->voiceProbability.load(),
          impl_->processedFrames.load(), impl_->droppedFrames.load()};
}
