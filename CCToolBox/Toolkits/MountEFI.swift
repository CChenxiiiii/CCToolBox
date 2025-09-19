//
//  MountEFI.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - 数据模型
struct PhysicalDisk: Identifiable, Hashable {
    let id: String
    let mediaName: String   // 真实硬盘名称
    let size: String
    let isInternal: Bool
    let isSSD: Bool
    let identifier: String
    
    var displayName: String { mediaName }   // 主标题
    var subtitle: String {
        "\(isInternal ? "内置" : "外置") · \(isSSD ? "SSD" : "HDD")"
    }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PhysicalDisk, rhs: PhysicalDisk) -> Bool { lhs.id == rhs.id }
}

// MARK: - 磁盘管理
class DiskManager: ObservableObject {
    @Published var physicalDisks: [PhysicalDisk] = []
    @Published var selectedDisk: PhysicalDisk?
    @Published var isLoading = false
    @Published var statusMessage = "选择硬盘挂载 EFI 分区"
    
    var debugLog: String = ""
    
    func fetchPhysicalDisks() {
        isLoading = true
        statusMessage = "正在扫描硬盘..."
        physicalDisks.removeAll()
        debugLog = ""
        log("开始扫描 GPT 物理硬盘...")
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let list = scanGPTPhysicalDisks()
            DispatchQueue.main.async { [self] in
                self.physicalDisks = list
                self.isLoading = false
                self.statusMessage = list.isEmpty
                    ? "未检测到 GPT 物理硬盘"
                    : "找到 \(list.count) 个 GPT 物理硬盘"
            }
        }
    }
    
    // MARK: - 扫描 GPT 物理盘（修复版）
    private func scanGPTPhysicalDisks() -> [PhysicalDisk] {
        guard let raw = run("/usr/sbin/diskutil", ["list"]) else { return [] }
        log("diskutil list 输出:\n\(raw)")

        let pattern = #"^(?<path>/dev/disk\d+)\s.*\((?<type>internal|external),\s*physical\):[\s\S]*?GUID_partition_scheme"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let matches = regex.matches(in: raw, range: range)

        var disks: [PhysicalDisk] = []
        for match in matches {
            guard let pathRange = Range(match.range(withName: "path"), in: raw),
                  let typeRange = Range(match.range(withName: "type"), in: raw) else { continue }

            let path = String(raw[pathRange])
            let id   = String(path.dropFirst(5))
            let isInternal = raw[typeRange] == "internal"

            guard let plist = run("/usr/sbin/diskutil", ["info", "-plist", id]),
                  let data = plist.data(using: .utf8),
                  let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let bytes = dict["TotalSize"] as? Int64,
                  let mediaName = dict["MediaName"] as? String,
                  !mediaName.isEmpty else { continue }

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useTB]
            formatter.countStyle = .file
            let size = formatter.string(fromByteCount: bytes)

            let isSSD = checkIfSSD(diskID: id)

            disks.append(PhysicalDisk(
                id: id,
                mediaName: mediaName,
                size: size,
                isInternal: isInternal,
                isSSD: isSSD,
                identifier: id))
        }
        log("解析到 \(disks.count) 个 GPT 物理硬盘")
        return disks
    }

    // MARK: - SSD 判别（修复版）
    private func checkIfSSD(diskID: String) -> Bool {
        guard let info = run("/usr/sbin/diskutil", ["info", diskID]) else { return false }
        return info.range(of: #"SSD|Solid State"#, options: .regularExpression) != nil
    }
    
    // MARK: - 挂载 EFI
    func mountEFIPartition() {
        guard let disk = selectedDisk else {
            statusMessage = "请先选择硬盘"
            return
        }
        let efi = "\(disk.identifier)s1"
        log("尝试挂载 \(efi)")
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let script = "do shell script \"diskutil mount \(efi)\" with administrator privileges"
            let result = runAppleScript(script)
            DispatchQueue.main.async { [self] in
                self.isLoading = false
                if let err = result.error {
                    self.statusMessage = "错误: \(err)"
                    self.log("挂载错误: \(err)")
                } else {
                    self.statusMessage = "已挂载 \(efi)"
                    self.log("挂载成功: \(efi)")
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes/EFI"))
                }
            }
        }
    }
    
    // MARK: - 工具方法
    private func run(_ path: String, _ args: [String]) -> String? {
        let task = Process()
        task.launchPath = path
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return nil }
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func runAppleScript(_ source: String) -> (output: String?, error: String?) {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return (result?.stringValue, (error?["NSAppleScriptErrorMessage"] as? String))
    }
    
    private func log(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog += "[\(ts)] \(message)\n"
        if debugLog.count > 10000 {
            debugLog = String(debugLog.suffix(10000))
        }
    }
}

// MARK: - SwiftUI 界面
struct MountEFI: View {
    @StateObject private var diskManager = DiskManager()
    @State private var showDebugLog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EFI 分区挂载工具").font(.largeTitle).bold()
            Text("选择 GPT 物理硬盘挂载 EFI 分区").foregroundColor(.secondary)
            
            diskList
                .glassEffect()
                .cornerRadius(30)
            statusSection
            actionButtons
            
            HStack {
                Spacer()
                Button("调试日志") { showDebugLog.toggle() }.font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 520)
        .onAppear { diskManager.fetchPhysicalDisks() }
        .sheet(isPresented: $showDebugLog) { debugLogView }
    }
    
    private var diskList: some View {
        Group {
            if diskManager.isLoading {
                VStack { ProgressView(); Text("扫描中...").padding(.top, 8) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diskManager.physicalDisks.isEmpty {
                VStack {
                    Image(systemName: "externaldrive.badge.xmark").font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("未检测到 GPT 物理硬盘").foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $diskManager.selectedDisk) {
                    ForEach(diskManager.physicalDisks) { disk in
                        HStack {
                            Image(systemName: diskIcon(for: disk))
                                .font(.title2)
                                .foregroundColor(disk.isInternal ? .blue : .green)
                            
                            VStack(alignment: .leading) {
                                Text(disk.displayName).font(.headline)
                                Text(disk.subtitle).font(.caption).foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if diskManager.selectedDisk?.id == disk.id {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                            }
                        }
                        .padding(8)
                        .tag(disk)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(height: 200)
    }
    
    private func diskIcon(for disk: PhysicalDisk) -> String {
        if disk.isSSD {
            return disk.isInternal ? "internaldrive" : "externaldrive.badge.ssd"
        } else {
            return disk.isInternal ? "internaldrive" : "externaldrive"
        }
    }
    
    private var statusSection: some View {
        HStack {
            Image(systemName: "info.circle")
            Text(diskManager.statusMessage).font(.callout).lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background).opacity(0.7))
    }
    
    private var actionButtons: some View {
        HStack {
            Button(action: diskManager.fetchPhysicalDisks) {
                HStack { Image(systemName: "arrow.clockwise"); Text("刷新") }
            }
            Spacer()
            Button(action: diskManager.mountEFIPartition) {
                HStack { Image(systemName: "externaldrive.badge.plus"); Text("挂载 EFI") }
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(diskManager.selectedDisk == nil || diskManager.isLoading)
        }
    }
    
    private var debugLogView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("调试日志").font(.title)
                Spacer()
                Button("关闭") { showDebugLog = false }
            }.padding()
            
            ScrollView {
                Text(diskManager.debugLog)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
            }
            .frame(minWidth: 550, minHeight: 350)
            
            HStack {
                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(diskManager.debugLog, forType: .string)
                }
                Button("保存") { saveLogToFile() }
                Spacer()
                Button("清除") { diskManager.debugLog = "" }
            }.padding()
        }.padding()
    }
    
    private func saveLogToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "efi_mounter_log_\(Int(Date().timeIntervalSince1970)).txt"
        panel.begin { if $0 == .OK, let url = panel.url {
            try? diskManager.debugLog.write(to: url, atomically: true, encoding: .utf8)
        }}
    }
}

// MARK: - 工具扩展
extension ByteCountFormatter {
    convenience init(then closure: (ByteCountFormatter) -> Void) {
        self.init()
        closure(self)
    }
}

// MARK: - 玻璃效果
extension View {
    @ViewBuilder func glassEffect() -> some View {
        if #available(macOS 12.0, *) {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else {
            self.background(RoundedRectangle(cornerRadius: 14).fill(Color(.windowBackgroundColor)).shadow(radius: 5))
        }
    }
}

// MARK: - 预览

#Preview(){
    MountEFI()
}
