//
//  FixSleep.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI
import IOKit
import Combine
import Foundation
import ServiceManagement

struct FixSleep: View {
    @State private var logMessages: [LogMessage] = []
    @State private var showDebug = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isWorking = false
    @State private var progress: Double = 0.0
    @State private var currentCommandIndex = 0
    @State private var totalCommands = 10
    
    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "powersleep")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                Text("睡眠修复工具")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .padding(.top)
            
            // 进度条
            if isWorking {
                VStack(alignment: .leading) {
                    Text("进度: \(currentCommandIndex)/\(totalCommands)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(height: 8)
                        .padding(.bottom, 5)
                }
                .padding(.horizontal)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(logMessages) { message in
                            Text("\(message.timestamp): \(message.text)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(message.color)
                                .id(message.id)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .onAppear {
                        addLog("就绪，点击开始修复", color: .gray)
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: logMessages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
            .padding([.horizontal, .bottom])
            
            Toggle("显示调试信息", isOn: $showDebug)
                .padding(.horizontal)
            
            Button(action: startFix) {
                HStack {
                    if isWorking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isWorking ? "修复中..." : "开始修复")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isWorking ? Color.blue.opacity(0.7) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isWorking)
            .padding([.horizontal, .bottom])
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("管理员权限请求"),
                message: Text(alertMessage),
                primaryButton: .default(Text("继续")) {
                    executeWithPrivileges()
                },
                secondaryButton: .cancel(Text("取消")) {
                    addLog("❌ 用户取消了操作", color: .red)
                    isWorking = false
                }
            )
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard !logMessages.isEmpty else { return }
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(logMessages.last!.id, anchor: .bottom)
            }
        }
    }
    
    private func startFix() {
        isWorking = true
        progress = 0.0
        currentCommandIndex = 0
        logMessages.removeAll()
        
        addLog("通用睡眠修复准备开始", color: .primary)
        addLog("正在检查电源管理X86PlatformPlugin", color: .primary)
        
        DispatchQueue.global().async {
            if self.checkX86PlatformPlugin() {
                self.addLog("电源管理正常 ✅", color: .green)
                self.addLog("🔒 请求管理员权限中...", color: .primary)
                
                DispatchQueue.main.async {
                    self.alertMessage = "此操作需要管理员权限来修改系统电源设置"
                    self.showAlert = true
                }
            } else {
                self.addLog("❌ 请检查电源管理后重试", color: .red)
                DispatchQueue.main.async {
                    self.isWorking = false
                }
            }
        }
    }
    
    private func executeWithPrivileges() {
        addLog("✅ 管理员权限请求成功", color: .green)
        
        let commands = [
            "sleep": "1",
            "displaysleep": "0",
            "disksleep": "0",
            "womp": "0",
            "powernap": "0",
            "standby": "0",
            "autopoweroff": "0",
            "proximitywake": "0",
            "tcpkeepalive": "0",
            "hibernatemode": "0"
        ]
        
        totalCommands = commands.count
        currentCommandIndex = 0
        progress = 0.0
        
        DispatchQueue.global().async {
            // 创建临时脚本文件
            let tempScriptURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fix_sleep_\(UUID().uuidString).sh")
            let scriptContent = commands.map { (key, value) in
                "sudo pmset -a \(key) \(value)"
            }.joined(separator: "\n")
            
            do {
                try scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            } catch {
                self.addLog("❌ 创建临时脚本失败: \(error.localizedDescription)", color: .red)
                DispatchQueue.main.async {
                    self.isWorking = false
                }
                return
            }
            
            // 使用AppleScript执行脚本并请求权限
            let appleScript = NSAppleScript(source: """
                do shell script "\(tempScriptURL.path)" with administrator privileges
                """)
            
            var errorInfo: NSDictionary?
            let result = appleScript?.executeAndReturnError(&errorInfo)
            
            // 清理临时脚本
            try? FileManager.default.removeItem(at: tempScriptURL)
            
            if let error = errorInfo {
                self.addLog("❌ 执行失败: 需要管理员权限", color: .red)
                if self.showDebug {
                    self.addLog("DEBUG: \(error)", color: .orange)
                }
                
                // 回退方法：逐个执行命令
                self.executeCommandsIndividually(commands: commands)
            } else if let output = result?.stringValue {
                self.addLog("✅ 所有命令执行成功", color: .green)
                
                // 显示每个命令的执行结果
                for (key, value) in commands {
                    self.addLog("✅ 执行成功: pmset \(key) -> \(value)", color: .green)
                }
                
                if self.showDebug {
                    self.addLog("DEBUG: \(output)", color: .orange)
                }
                
                self.showCompletionMessage()
            } else {
                self.addLog("✅ 命令执行完成", color: .green)
                self.showCompletionMessage()
            }
        }
    }
    
    private func executeCommandsIndividually(commands: [String: String]) {
        addLog("⚠️ 尝试逐个执行命令...", color: .orange)
        
        for (index, (key, value)) in commands.enumerated() {
            currentCommandIndex = index + 1
            progress = Double(index + 1) / Double(commands.count)
            
            let command = "pmset -a \(key) \(value)"
            addLog("执行: sudo \(command)", color: .secondary)
            
            let result = runShellCommand("sudo \(command)")
            
            if result.success {
                addLog("✅ 执行成功: pmset \(key) -> \(value)", color: .green)
            } else {
                addLog("❌ 执行失败: pmset \(key) -> \(value)", color: .red)
                if showDebug {
                    addLog("DEBUG: \(result.output)", color: .orange)
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        showCompletionMessage()
    }
    
    private func showCompletionMessage() {
        // 显示完整的建议
        addLog("睡眠修复完毕，请尝试睡眠", color: .primary)
        addLog("若失败可以尝试：", color: .primary)
        addLog("1️⃣ 无法自动睡眠: 系统设置（偏好设置） -> 能耗（节能） -> 启用电源小憩 -> 启用", color: .blue)
        addLog("   OpenCore -> Kernel -> Patch -> com.apple.driver.AppleRTC -> 启用", color: .blue)
        addLog("2️⃣ 睡眠秒醒: 注入SSDT-GPRW及其配套补丁", color: .blue)
        
        DispatchQueue.main.async {
            self.isWorking = false
        }
    }
    
    private func checkX86PlatformPlugin() -> Bool {
        #if arch(x86_64)
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }
        #else
        // Apple Silicon 使用 kIOMainPortDefault
        let masterPort = kIOMainPortDefault
        #endif
        
        let service = IOServiceGetMatchingService(
            masterPort,
            IOServiceMatching("X86PlatformPlugin")
        )
        
        if service != IO_OBJECT_NULL {
            IOObjectRelease(service)
            return true
        }
        return false
    }
    
    private struct RunResult {
        let success: Bool
        let output: String
    }
    
    private func runShellCommand(_ command: String) -> RunResult {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            return RunResult(
                success: task.terminationStatus == 0,
                output: output
            )
        } catch {
            return RunResult(
                success: false,
                output: error.localizedDescription
            )
        }
    }
    
    private func addLog(_ text: String, color: Color) {
        DispatchQueue.main.async {
            let newMessage = LogMessage(text: text, color: color)
            self.logMessages.append(newMessage)
        }
    }
}

struct LogMessage: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    let timestamp: String
    
    init(text: String, color: Color) {
        self.text = text
        self.color = color
        self.timestamp = Self.formattedDate()
    }
    
    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
