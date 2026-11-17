import Darwin
import Foundation

struct NativePerformanceMetrics {
    var cpuPercent = 0.0
    var memoryMB = 0.0
}

final class NativePerformanceSampler {
    private var previousCPUTime = 0.0
    private var previousWallTime = ProcessInfo.processInfo.systemUptime

    func sample() -> NativePerformanceMetrics {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let cpuTime = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
            + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        let wallTime = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0.001, wallTime - previousWallTime)
        let cpu = previousCPUTime == 0 ? 0 : max(0, (cpuTime - previousCPUTime) / elapsed * 100)
        previousCPUTime = cpuTime
        previousWallTime = wallTime

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let memory = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        } == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
        return NativePerformanceMetrics(cpuPercent: cpu, memoryMB: memory)
    }
}
