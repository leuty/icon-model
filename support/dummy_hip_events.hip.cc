#include <hip/hip_runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

hipError_t hipEventRecord(hipEvent_t, hipStream_t) {
  return hipSuccess;
}

hipError_t hipStreamWaitEvent(hipStream_t, hipEvent_t, unsigned int) {
  return hipSuccess;
}

#ifdef __cplusplus
}
#endif
