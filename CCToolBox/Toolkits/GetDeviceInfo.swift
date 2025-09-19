//
//  GetDeviceInfo.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import Foundation   // ← 必须引入，提供 Data 类型
import IOKit
import Metal
internal import System

enum LogLevel: String {
    case cmd  = "[CMD]"
    case out  = "[OUT]"
    case info = "[INFO]"
    case ok   = "[OK]"
    case err  = "[ERR]"
}

// MARK: - 读取硬件标识符
func rawModelIdentifier() -> String {
    let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                              IOServiceMatching("IOPlatformExpertDevice"))
    defer { IOObjectRelease(service) }

    guard
        let modelData = IORegistryEntryCreateCFProperty(service,
                                                        "model" as CFString,
                                                        kCFAllocatorDefault,
                                                        0)?.takeRetainedValue() as? Data,
        let cString = String(data: modelData, encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
    else {
        return "Unknown"
    }
    return cString
}

// MARK: - 对外统一接口

struct BoardIDFetcher {
    static func fetch(log: (String, LogLevel) -> Void) -> String? {
        // 1. 构造命令
        let cmd = #"ioreg -p IODeviceTree -d 1 -k board-id | grep -o 'board-id.*<[^>]*>' | sed -E 's/.*<"([^"]+)".*/\1/'"#
        log("ioreg -p IODeviceTree -d 1 -k board-id", .cmd)

        // 2. 执行
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments  = ["-c", cmd]

        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError  = stderr

        task.launch()
        task.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        log(outStr.isEmpty ? "(无标准输出)" : outStr, .out)
        if !errStr.isEmpty { log(errStr, .err) }

        // 3. 成功判定
        if task.terminationStatus == 0, !outStr.isEmpty {
            log("成功解析 Board-ID", .ok)
            return outStr
        } else {
            log("无法解析 Board-ID", .err)
            return nil
        }
    }
}

/// 返回友好型号；未命中或 ARM 时返回原始标识符
func friendlyMacName() -> String {
    let id = rawModelIdentifier()
    return x86MarketingMap[id] ?? id
}

/// 返回对应 SF Symbol
func macIconName() -> String {
    guard let model = x86MarketingMap[rawModelIdentifier()]?.lowercased() else {
        return "cpu.fill"   // ARM 或未收录
    }
    if model.contains("macbook air") { return "macbook" }
    if model.contains("macbook pro") { return "macbook" }
    if model.contains("macbook")     { return "macbook" }
    if model.contains("imac pro")    { return "desktopcomputer" }
    if model.contains("imac")        { return "desktopcomputer" }
    if model.contains("mac mini")    { return "macmini" }
    if model.contains("mac pro")     { return "macpro.gen3" }
    return "cpu.fill"
}

/// 2010 年以后全部 x86 Mac 的营销型号表
/// 数据来源：Apple 官方 Tech Specs、EveryMac、Mactracker
private let x86MarketingMap: [String: String] = [
    // MARK: - MacBook Air
    "MacBookAir3,1": "MacBook Air (11-inch, Late 2010)",
    "MacBookAir3,2": "MacBook Air (13-inch, Late 2010)",
    "MacBookAir4,1": "MacBook Air (11-inch, Mid 2011)",
    "MacBookAir4,2": "MacBook Air (13-inch, Mid 2011)",
    "MacBookAir5,1": "MacBook Air (11-inch, Mid 2012)",
    "MacBookAir5,2": "MacBook Air (13-inch, Mid 2012)",
    "MacBookAir6,1": "MacBook Air (11-inch, Mid 2013–2014)",
    "MacBookAir6,2": "MacBook Air (13-inch, Mid 2013–2014)",
    "MacBookAir7,1": "MacBook Air (11-inch, Early 2015)",
    "MacBookAir7,2": "MacBook Air (13-inch, Early 2015–2017)",
    
    // MARK: - MacBook Pro
    "MacBookPro6,1": "MacBook Pro (17-inch, Mid 2010)",
    "MacBookPro6,2": "MacBook Pro (15-inch, Mid 2010)",
    "MacBookPro7,1": "MacBook Pro (13-inch, Mid 2010)",
    "MacBookPro8,1": "MacBook Pro (13-inch, Early–Late 2011)",
    "MacBookPro8,2": "MacBook Pro (15-inch, Early–Late 2011)",
    "MacBookPro8,3": "MacBook Pro (17-inch, Early–Late 2011)",
    "MacBookPro9,1": "MacBook Pro (15-inch, Mid 2012)",
    "MacBookPro9,2": "MacBook Pro (13-inch, Mid 2012)",
    "MacBookPro10,1": "MacBook Pro (Retina, 15-inch, Mid 2012)",
    "MacBookPro10,2": "MacBook Pro (Retina, 13-inch, Late 2012)",
    "MacBookPro11,1": "MacBook Pro (Retina, 13-inch, Late 2013–2014)",
    "MacBookPro11,2": "MacBook Pro (Retina, 15-inch, Late 2013–2014)",
    "MacBookPro11,3": "MacBook Pro (Retina, 15-inch, Mid 2015)",
    "MacBookPro11,4": "MacBook Pro (Retina, 15-inch, Mid 2015)",
    "MacBookPro11,5": "MacBook Pro (Retina, 15-inch, Mid 2015)",
    "MacBookPro12,1": "MacBook Pro (Retina, 13-inch, Early 2015)",
    "MacBookPro13,1": "MacBook Pro (13-inch, 2016, 2×TB3)",
    "MacBookPro13,2": "MacBook Pro (13-inch, 2016, 4×TB3)",
    "MacBookPro13,3": "MacBook Pro (15-inch, 2016)",
    "MacBookPro14,1": "MacBook Pro (13-inch, 2017, 2×TB3)",
    "MacBookPro14,2": "MacBook Pro (13-inch, 2017, 4×TB3)",
    "MacBookPro14,3": "MacBook Pro (15-inch, 2017)",
    "MacBookPro15,1": "MacBook Pro (15-inch, 2018–2019)",
    "MacBookPro15,2": "MacBook Pro (13-inch, 2018–2019, 4×TB3)",
    "MacBookPro15,3": "MacBook Pro (15-inch, 2019)",
    "MacBookPro15,4": "MacBook Pro (13-inch, 2019, 2×TB3)",
    "MacBookPro16,1": "MacBook Pro (16-inch, 2019)",
    "MacBookPro16,2": "MacBook Pro (13-inch, 2020, 4×TB3)",
    "MacBookPro16,3": "MacBook Pro (13-inch, 2020, 2×TB3)",
    "MacBookPro16,4": "MacBook Pro (16-inch, 2019)",

    // MARK: - MacBook (12-inch)
    "MacBook8,1":  "MacBook (Retina, 12-inch, Early 2015)",
    "MacBook9,1":  "MacBook (Retina, 12-inch, Early 2016)",
    "MacBook10,1": "MacBook (Retina, 12-inch, 2017)",

    // MARK: - iMac
    "iMac11,2": "iMac (21.5-inch, Mid 2010)",
    "iMac11,3": "iMac (27-inch, Mid 2010)",
    "iMac12,1": "iMac (21.5-inch, Mid 2011)",
    "iMac12,2": "iMac (27-inch, Mid 2011)",
    "iMac13,1": "iMac (21.5-inch, Late 2012)",
    "iMac13,2": "iMac (27-inch, Late 2012)",
    "iMac14,1": "iMac (21.5-inch, Late 2013)",
    "iMac14,2": "iMac (27-inch, Late 2013)",
    "iMac14,3": "iMac (21.5-inch, Late 2013/NVIDIA)",
    "iMac14,4": "iMac (21.5-inch, Mid 2014)",
    "iMac15,1": "iMac (Retina 5K, 27-inch, Late 2014–2015)",
    "iMac16,1": "iMac (21.5-inch, Late 2015)",
    "iMac16,2": "iMac (21.5-inch, Late 2015)",
    "iMac17,1": "iMac (Retina 5K, 27-inch, Late 2015)",
    "iMac18,1": "iMac (21.5-inch, 2017)",
    "iMac18,2": "iMac (Retina 4K, 21.5-inch, 2017)",
    "iMac18,3": "iMac (Retina 5K, 27-inch, 2017)",
    "iMac19,1": "iMac (Retina 5K, 27-inch, 2019)",
    "iMac19,2": "iMac (Retina 4K, 21.5-inch, 2019)",
    "iMac20,1": "iMac (Retina 5K, 27-inch, 2020)",
    "iMac20,2": "iMac (Retina 5K, 27-inch, 2020)",
    
    // MARK: - iMac Pro
    "iMacPro1,1": "iMac Pro (2017)",

    // MARK: - Mac mini
    "Macmini4,1": "Mac mini (Mid 2010)",
    "Macmini5,1": "Mac mini (Mid 2011)",
    "Macmini5,2": "Mac mini (Mid 2011, Server)",
    "Macmini5,3": "Mac mini (Mid 2011, AMD)",
    "Macmini6,1": "Mac mini (Late 2012)",
    "Macmini6,2": "Mac mini (Late 2012, Server)",
    "Macmini7,1": "Mac mini (Late 2014)",
    "Macmini8,1": "Mac mini (2018)",

    // MARK: - Mac Pro
    "MacPro5,1": "Mac Pro (Mid 2010–2012)",
    "MacPro6,1": "Mac Pro (Late 2013)",
    "MacPro7,1": "Mac Pro (2019)",

    // MARK: - Xserve
    "Xserve3,1": "Xserve (Early 2009)"
]







// GetCPU

struct CPUInfo {
    let model: String   // “Apple M3 Pro”
    let freqGHz: Double // 2.60
    let physicalCores: Int
    let logicalCores: Int
}

func currentCPUInfo() -> CPUInfo {
    // 1) 型号
    let model = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }()

    // 2) 主频 (GHz)
    let freqGHz = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPlatformDevice"))
        defer { IOObjectRelease(service) }
        guard
            let cfFreq = IORegistryEntryCreateCFProperty(service,
                                                         "CPU Frequency" as CFString,
                                                         kCFAllocatorDefault,
                                                         0)?
                .takeRetainedValue() as? NSNumber
        else {
            // 回退：用 sysctl 频率（MHz → GHz）
            var freqMHz: Int = 0
            var len = MemoryLayout<Int>.size
            sysctlbyname("hw.cpufrequency", &freqMHz, &len, nil, 0)
            return Double(freqMHz) / 1_000_000_000
        }
        return cfFreq.doubleValue / 1_000_000_000
    }()

    // 3) 核心数
    let physical = {
        var n: Int32 = 0
        var len = MemoryLayout<Int32>.size
        sysctlbyname("hw.physicalcpu", &n, &len, nil, 0)
        return Int(n)
    }()

    let logical = {
        var n: Int32 = 0
        var len = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &n, &len, nil, 0)
        return Int(n)
    }()

    return CPUInfo(model: model,
                   freqGHz: Double(round(freqGHz * 100) / 100),
                   physicalCores: physical,
                   logicalCores: logical)
}

// GPU Info

/// GPU 信息结构体
///
public struct GPUInfo: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let vendor: String
    public let memoryGB: Int
}

public enum GPUReader {
    public static func read() -> [GPUInfo] {
        let devices = MTLCopyAllDevices()
        var gpus: [GPUInfo] = []
        
        for device in devices {
            let name = device.name
            let vendor = getVendor(from: name)
            let bytes = device.recommendedMaxWorkingSetSize
            let gb = Int((bytes + 512 * 1024 * 1024) / 1024 / 1024 / 1024)
            let gpu = GPUInfo(name: name, vendor: vendor, memoryGB: gb)
            gpus.append(gpu)
        }

        if gpus.contains(where: { $0.vendor == "Apple" }) {
            return gpus
        }

        let discrete = gpus.filter { $0.vendor == "AMD" || $0.vendor == "NVIDIA" }
        return discrete.isEmpty ? gpus.filter { $0.vendor == "Intel" } : discrete
    }

    private static func getVendor(from name: String) -> String {
        let lowerName = name.lowercased()
        if lowerName.contains("apple") { return "Apple" }
        if lowerName.contains("amd") { return "AMD" }
        if lowerName.contains("nvidia") { return "NVIDIA" }
        if lowerName.contains("intel") { return "Intel" }
        return "Unknown"
    }
}





// RAM

public struct MemoryInfo: Identifiable, Hashable {
    public let id = UUID()
    public let capacityGB: Int
}

public enum MemoryReader {
    public static func read() -> MemoryInfo {
        let capacity = memoryCapacityGB()
        return MemoryInfo(capacityGB: capacity)
    }
    
    // MARK: - 真实容量
    private static func memoryCapacityGB() -> Int {
        var bytes: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &bytes, &len, nil, 0)
        return Int(bytes) / 1024 / 1024 / 1024
    }
}




// OS Version

private func macOSCodeName(_ major: Int, _ minor: Int, _ patch: Int = 0) -> String {
    // 1️⃣ 去掉 patch，只保留主.次
    let key = "\(major).\(minor)"

    // 2️⃣ 查表
    let table: [String: String] = [
        "12.0":  "Monterey",
        "13.0":  "Ventura",
        "14.0":  "Sonoma",
        "15.0":  "Sequoia",
        "26.0":  "Tahoe"
    ]
    return table[key] ?? ""
}

private func getBuildNumber() -> String {
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var build = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &build, &size, nil, 0)
    return String(cString: build)
}

func macOSPrettyString() -> String {
    let v   = ProcessInfo.processInfo.operatingSystemVersion
    let build = getBuildNumber()
    let code = macOSCodeName(v.majorVersion, v.minorVersion, v.patchVersion)
    let codePart = code.isEmpty ? "" : " \(code)"
    return "macOS \(v.majorVersion).\(v.minorVersion)\(codePart) (\(build))"
}

private func macOSVersionString() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "\(v.majorVersion).\(v.minorVersion)"
}


// Serial Number

/// 返回主板序列号，失败返回空字符串
func serialNumber() -> String {
    let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                              IOServiceMatching("IOPlatformExpertDevice"))
    defer { IOObjectRelease(service) }
    
    guard let serial = IORegistryEntryCreateCFProperty(service,
                                                       "IOPlatformSerialNumber" as CFString,
                                                       kCFAllocatorDefault,
                                                       0)?.takeRetainedValue() as? String else {
        return ""
    }
    return serial
}

 

//Disk

public struct DiskSpaceInfo {
    public let totalGB: Int
    public let freeGB: Int
}

/// 直接返回启动磁盘“可用/总”字符串，例如 "120 GB / 512 GB"

public func diskSpaceString() -> String {
    do {
        // 获取启动磁盘的URL
        let url = URL(fileURLWithPath: "/")
        
        // 定义要查询的资源键
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        
        // 获取磁盘空间信息
        let values = try url.resourceValues(forKeys: keys)
        
        // 计算总空间和可用空间（转换为GB）
        let totalCapacity = (values.volumeTotalCapacity ?? 0) / (1024 * 1024 * 1024)
        let availableCapacity = (values.volumeAvailableCapacity ?? 0) / (1024 * 1024 * 1024)
        
        // 返回格式化后的字符串
        return "\(availableCapacity) GB / \(totalCapacity) GB"
    } catch {
        // 如果发生错误，返回默认值
        return "0 GB / 0 GB"
    }
}
