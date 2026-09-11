#include <array>
#include <cstddef>
#include <cmath>
#include <cstdlib>

extern "C" {
#include "rnnoise.h"
}

int main() {
  if (rnnoise_get_frame_size() != 480) return EXIT_FAILURE;

  DenoiseState* state = rnnoise_create(nullptr);
  if (!state) return EXIT_FAILURE;

  std::array<float, 480> input{};
  std::array<float, 480> output{};
  for (size_t index = 0; index < input.size(); ++index) {
    input[index] = 1200.0F * std::sin(static_cast<float>(index) * 0.05F);
  }

  const float probability = rnnoise_process_frame(state, output.data(), input.data());
  rnnoise_destroy(state);

  if (!std::isfinite(probability) || probability < 0.0F || probability > 1.0F) {
    return EXIT_FAILURE;
  }
  for (const float sample : output) {
    if (!std::isfinite(sample)) return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}
