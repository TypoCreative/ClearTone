#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <vector>

class AudioEngine final {
public:
  struct Metrics {
    float inputLevel = 0.0F;
    float outputLevel = 0.0F;
    float voiceProbability = 0.0F;
    unsigned long long processedFrames = 0;
    unsigned long long droppedFrames = 0;
  };

  struct Device {
    std::wstring id;
    std::wstring name;
  };

  using StatusCallback = std::function<void(const std::wstring&)>;

  AudioEngine();
  ~AudioEngine();
  AudioEngine(const AudioEngine&) = delete;
  AudioEngine& operator=(const AudioEngine&) = delete;

  static std::vector<Device> outputDevices();
  bool start(StatusCallback callback, std::wstring outputDeviceId);
  void stop();
  [[nodiscard]] bool isRunning() const noexcept;
  void setStrength(float value) noexcept;
  [[nodiscard]] Metrics metrics() const noexcept;

private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
