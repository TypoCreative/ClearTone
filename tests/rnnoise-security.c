#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rnnoise.h"
#include "nnet.h"

int main(void) {
  union { int alignment; unsigned char bytes[256]; } blob = {0};
  WeightArray *list = NULL;
  LinearLayer layer;
  WeightArray empty[] = {{NULL, 0, 0, NULL}};
  int invalid_index[] = {-1, INT_MAX};
  WeightArray sparse[] = {{"idx", WEIGHT_TYPE_int, sizeof(invalid_index), invalid_index}, {NULL, 0, 0, NULL}};
  assert(rnnoise_model_from_file(NULL) == NULL);
  assert(rnnoise_model_from_filename(NULL) == NULL);
  assert(rnnoise_model_from_filename("/nonexistent-cleartone-model") == NULL);
  assert(rnnoise_model_from_buffer(NULL, 8) == NULL);
  assert(rnnoise_model_from_buffer(blob.bytes, -1) == NULL);
  rnnoise_model_free(NULL);
  /* Buffer models must not close an uninitialized FILE pointer when freed. */
  RNNModel *model = rnnoise_model_from_buffer(blob.bytes, sizeof(blob.bytes));
  assert(model != NULL);
  assert(rnnoise_create(model) == NULL);
  rnnoise_model_free(model);
  FILE *file = tmpfile();
  assert(file != NULL);
  assert(rnnoise_model_from_file(file) == NULL);
  fclose(file);
  assert(parse_weights(&list, blob.bytes, -1) == -1 && list == NULL);
  assert(parse_weights(NULL, blob.bytes, sizeof(blob.bytes)) == -1);
  assert(linear_init(&layer, empty, NULL, NULL, NULL, NULL, "missing", NULL, NULL, 8, 8) != 0);
  assert(linear_init(&layer, sparse, NULL, NULL, NULL, NULL, "idx", NULL, NULL, 8, 8) != 0);
  invalid_index[0] = INT_MAX;
  assert(linear_init(&layer, sparse, NULL, NULL, NULL, NULL, "idx", NULL, NULL, 8, 8) != 0);
  /* Exercise malformed/truncated headers with sanitizers enabled. */
  uint32_t seed = 1;
  for (int trial = 0; trial < 2000; trial++) {
    for (size_t j = 0; j < sizeof(blob.bytes); j++) {
      seed = seed * 1664525u + 1013904223u;
      blob.bytes[j] = (unsigned char)(seed >> 24);
    }
    int result = parse_weights(&list, blob.bytes, trial % sizeof(blob.bytes));
    if (result >= 0) free(list);
  }
  DenoiseState *state = rnnoise_create(NULL);
  assert(state != NULL);
  float input[480] = {0}, output[480];
  rnnoise_process_frame(state, output, input);
  rnnoise_destroy(state);
  puts("RNNoise security regression checks passed.");
  return 0;
}
