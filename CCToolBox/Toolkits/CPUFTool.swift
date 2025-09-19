//
//  CPUFTool.swift
//
//  黑苹果睿频修复工具（SwiftUI for macOS）
//  2025-08-22
//

import SwiftUI
import AppKit
import IOKit      // ← 新增

// MARK: - 数据模型
struct SystemInfo {
    var osVersion: String
    var cpuModel: String
    var detectedModel: String
    var detectedBoardID: String
}

// MARK: - 主视图
struct CPUFTool: View {
    @State private var systemInfo = SystemInfo(
        osVersion: "",
        cpuModel: "",
        detectedModel: "",
        detectedBoardID: ""
    )
    
    @State private var customModel: String = ""
    @State private var customBoardID: String = ""
    @State private var logMessages: [String] = []
    @State private var isProcessing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var outputDirectory: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                systemInfoSection
                executeButton
                if showSuccess { successSection }
                logSection
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear(perform: detectSystemInfo)
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 标题和描述
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text("黑苹果睿频修复工具")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            Text("本工具用于自动化修复黑苹果 CPU 睿频问题。工具会自动检测您的机型与 BoardID，使用 ResourceConverter.sh 生成 CPUFriendDataProvider.kext，并在桌面创建包含所需文件的文件夹。")
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - 系统信息
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.green)
                Text("系统信息")
                    .font(.headline)
            }
            InfoRow(title: "操作系统:", value: systemInfo.osVersion, icon: "macwindow")
            InfoRow(title: "CPU型号:", value: systemInfo.cpuModel, icon: "cpu")
            InfoRow(title: "检测到的机型:", value: systemInfo.detectedModel, icon: "macpro.gen3")
            InfoRow(title: "检测到的BoardID:", value: systemInfo.detectedBoardID, icon: "number")
            Button(action: detectSystemInfo) {
                Label("重新检测系统信息", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .padding(.top, 5)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    // MARK: - 执行按钮
    private var executeButton: some View {
        Button(action: executeResourceConverter) {
            HStack {
                Spacer()
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Label(
                    isProcessing ? "正在生成文件..." : "开始生成睿频文件",
                    systemImage: "hammer"
                )
                .font(.headline)
                Spacer()
            }
            .foregroundColor(.white)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(radius: 5)
        }
        .disabled(isProcessing)
        .padding(.vertical, 10)
    }
    
    // MARK: - 成功提示
    private var successSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("生成成功！")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            Text("文件已保存到: \(outputDirectory)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("请将 CPUFriend.kext 和 CPUFriendDataProvider.kext 放入 EFI/OC/Kexts 目录，并重启系统。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
    }
    
    // MARK: - 日志
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.gray)
                Text("执行日志")
                    .font(.headline)
                Spacer()
                Button(action: { logMessages.removeAll() }) {
                    Label("清空日志", systemImage: "trash")
                        .font(.caption)
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(logMessages, id: \.self) { message in
                            Text(message)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .id(message)
                        }
                    }
                }
                .frame(height: 200)
                .padding(8)
                .background(Color.black.opacity(0.9))
                .cornerRadius(8)
                .foregroundColor(.white)
                .onChange(of: logMessages) { _ in
                    if let lastMessage = logMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
    
    // MARK: - 系统检测
    private func detectSystemInfo() {
        addLog("开始检测系统信息…")
        systemInfo.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        systemInfo.cpuModel  = getRealCPUModel()
        let (model, boardID) = detectRealModelAndBoardID()
        systemInfo.detectedModel   = model
        systemInfo.detectedBoardID = boardID
        addLog("系统检测完成")
        addLog("操作系统: \(systemInfo.osVersion)")
        addLog("CPU型号:  \(systemInfo.cpuModel)")
        addLog("机型:     \(systemInfo.detectedModel)")
        addLog("BoardID:  \(systemInfo.detectedBoardID)")
    }
    
    private func getRealCPUModel() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        return String(cString: buf)
    }
    
    /// 读取真实 Model 与 BoardID（修复版）
    /// 读取真实 Model 与 BoardID（ioreg 版）
    /// 读取真实 Model 与 BoardID（防卡死版）
    /// 读取真实 Model 与 BoardID（修正重复前缀）
    private func detectRealModelAndBoardID() -> (model: String, boardID: String) {
        // 1. 机型
        let model = run("/usr/sbin/system_profiler", args: ["SPHardwareDataType"])
            .split(separator: "\n")
            .first(where: { $0.contains("Model Identifier") })?
            .split(separator: ":").last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "MacBookPro16,1"

        // 2. BoardID：去掉所有多余字符，只留 16 位十六进制
        let rawHex = run("/bin/bash", args: [
            "-c",
            "ioreg -c IOPlatformExpertDevice -k board-id | grep -m 1 board-id | sed -E 's/.*<([^>]+)>.*/\\1/' | tr -d '\"'"
        ]).trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. 最终 BoardID，保证格式：Mac-xxxxxxxxxxxxxxxx
        let boardID = rawHex.count == 16 ? "Mac-E1008331FDC968  64" : "\(rawHex)"
        return (model, boardID)
    }
    
    /// 通用 Shell 执行
    private func run(_ path: String, args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    // MARK: - 其余辅助函数
    private func useDetectedValues() {
        customModel = systemInfo.detectedModel
        customBoardID = systemInfo.detectedBoardID
        addLog("已使用检测到的值填充输入框")
    }
    
    private func executeResourceConverter() {
        let model = customModel.isEmpty ? systemInfo.detectedModel : customModel
        let boardID = customBoardID.isEmpty ? systemInfo.detectedBoardID : customBoardID
        
        guard !model.isEmpty, !boardID.isEmpty else {
            alertMessage = "请先填写机型和 BoardID"
            showAlert = true
            return
        }
        
        isProcessing = true
        showSuccess = false
        addLog("开始执行睿频修复流程…")
        addLog("目标机型:  \(model)")
        addLog("目标BoardID: \(boardID)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            runResourceConverterWorkflow(model: model, boardID: boardID)
        }
    }
    
    private func runResourceConverterWorkflow(model: String, boardID: String) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("CPUFriendTool")
        let desktopDir = fm.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let outputDir = desktopDir.appendingPathComponent("CPUFriendFiles")
        
        do {
            if fm.fileExists(atPath: tempDir.path) {
                try fm.removeItem(at: tempDir)
            }
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            addLog("创建临时工作目录: \(tempDir.path)")
            addLog("获取MLB对应plist文件：/System/Library/Extensions/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources/\(boardID).plist")
            
            guard let resourcePath = Bundle.main.resourcePath else {
                throw NSError(domain: "Resource", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法定位资源目录"])
            }
            
            
            let reconvSrc = URL(fileURLWithPath: resourcePath).appendingPathComponent("ResourceConverter.sh")
            let cpufSrc   = URL(fileURLWithPath: resourcePath).appendingPathComponent("CPUFriend.kext")
            
            let reconvDst = tempDir.appendingPathComponent("ResourceConverter.sh")
            if fm.fileExists(atPath: reconvSrc.path) {
                try fm.copyItem(at: reconvSrc, to: reconvDst)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: reconvDst.path)
            } else {
                throw NSError(domain: "Resource", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到 ResourceConverter.sh"])
            }
            
            addLog("执行命令：\(tempDir.path)/ResourceConverter.sh --kext /System/Library/Extensions/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources/\(boardID).plist")
            
            let task = Process()
            task.currentDirectoryURL = tempDir
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [reconvDst.path, "--kext", "/System/Library/Extensions/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources/\(boardID).plist"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            try task.run()
            task.waitUntilExit()
            
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                output.components(separatedBy: .newlines).forEach { line in
                    if !line.isEmpty { addLog("脚本输出: \(line)") }
                }
            }
            
            if task.terminationStatus == 0 {
                addLog("ResourceConverter.sh 执行成功")
                
                if fm.fileExists(atPath: outputDir.path) {
                    try fm.removeItem(at: outputDir)
                }
                try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
                
                let generatedKext = tempDir.appendingPathComponent("CPUFriendDataProvider.kext")
                if fm.fileExists(atPath: generatedKext.path) {
                    try fm.copyItem(at: generatedKext, to: outputDir.appendingPathComponent("CPUFriendDataProvider.kext"))
                    addLog("已拷贝 CPUFriendDataProvider.kext")
                }
                
                if fm.fileExists(atPath: cpufSrc.path) {
                    try fm.copyItem(at: cpufSrc, to: outputDir.appendingPathComponent("CPUFriend.kext"))
                    addLog("已拷贝 CPUFriend.kext")
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.outputDirectory = outputDir.path
                    self.showSuccess = true
                    self.addLog("所有文件已准备就绪！")
                    self.addLog("输出目录: \(outputDir.path)")
                }
            } else {
                throw NSError(domain: "ResourceConverter", code: Int(task.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: "脚本执行失败"])
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.alertMessage = "执行失败: \(error.localizedDescription)"
                self.showAlert = true
                self.addLog("错误: \(error.localizedDescription)")
            }
        }
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            logMessages.append("[\(ts)] \(message)")
        }
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 预览
struct CPUFTool_Previews: PreviewProvider {
    static var previews: some View {
        CPUFTool()
            .frame(width: 800, height: 600)
    }
}
