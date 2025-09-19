//
//  WithoutHeliPort.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI
import UniformTypeIdentifiers

struct WiFiConfig: Identifiable {
    let key: String
    var ssid: String
    var password: String
    var id: String { key }
}

struct WithoutHeliPort: View {
    @State private var kextURL: URL?
    @State private var wifiConfigs: [WiFiConfig] = []
    @State private var selectedConfig: WiFiConfig?
    @State private var showFilePicker = false
    @State private var showEditor = false
    @State private var showLogs = false
    @State private var logs: [String] = []
    @State private var isLoading = false
    @State private var editingSSID = ""
    @State private var editingPassword = ""
    @State private var editingKey = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Image(systemName: "wifi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
                
                Text("WiFi配置管理器")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 文件状态指示器
                if let url = kextURL {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                
                // 操作按钮
                HStack(spacing: 16) {
                    Button(action: reloadConfigs) {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(CircleButtonStyle(color: .blue))
                    .disabled(isLoading || kextURL == nil)
                    
                    Button(action: { showLogs.toggle() }) {
                        Image(systemName: "doc.text")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(CircleButtonStyle(color: .gray))
                    .sheet(isPresented: $showLogs) {
                        LogView(logs: $logs)
                    }
                    
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "folder")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(CircleButtonStyle(color: .blue))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
            
            Divider()
            
            // 主内容区域
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("正在处理...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxHeight: .infinity)
            } else if wifiConfigs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("请选择Kext文件")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("点击右上角的文件夹图标选择Kext文件")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("选择Kext文件") {
                        showFilePicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 20)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                VStack(spacing: 0) {
                    // 列表标题
                    HStack {
                        Text("WiFi配置")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(wifiConfigs.count)个项目")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    // WiFi配置列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(wifiConfigs) { config in
                                ConfigRow(
                                    config: config,
                                    isSelected: selectedConfig?.id == config.id,
                                    onSelect: {
                                        selectedConfig = config
                                    },
                                    onEdit: {
                                        editingSSID = config.ssid
                                        editingPassword = config.password
                                        editingKey = config.key
                                        showEditor = true
                                    }
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    
                    // 操作按钮
                    if selectedConfig != nil {
                        HStack {
                            Button("修改选中配置") {
                                if let config = selectedConfig {
                                    editingSSID = config.ssid
                                    editingPassword = config.password
                                    editingKey = config.key
                                    showEditor = true
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.white))
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showEditor) {
            EditorView(
                ssid: $editingSSID,
                password: $editingPassword,
                onSave: saveChanges,
                onCancel: { showEditor = false }
            )
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let plistURL = url.appendingPathComponent("Contents/Info.plist")
                if FileManager.default.fileExists(atPath: plistURL.path) {
                    kextURL = url
                    loadPlist(url: plistURL)
                    log("Kext已选择: \(url.lastPathComponent)")
                } else {
                    log("错误: 找不到Info.plist")
                }
            }
        case .failure(let error):
            log("错误: \(error.localizedDescription)")
        }
    }
    
    private func loadPlist(url: URL) {
        isLoading = true
        Task {
            do {
                // 读取文件
                let data = try Data(contentsOf: url)
                guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                    log("错误: 无法解析PLIST")
                    return
                }
                
                // 确保有20项配置
                let updated = ensureWiFiConfigsExist(plist: &plist)
                
                // 如果有更新，写回文件
                if updated {
                    let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                    try newData.write(to: url)
                    log("已更新配置文件")
                }
                
                // 解析配置
                let configs = parseWiFiConfigs(plist: plist)
                await MainActor.run {
                    wifiConfigs = configs
                    selectedConfig = configs.first
                    isLoading = false
                }
            } catch {
                log("错误: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
    
    private func ensureWiFiConfigsExist(plist: inout [String: Any]) -> Bool {
        guard var personalities = plist["IOKitPersonalities"] as? [String: Any],
              var itlwm = personalities["itlwm"] as? [String: Any] else {
            return false
        }
        
        var wifiConfig = itlwm["WiFiConfig"] as? [String: [String: String]] ?? [:]
        var updated = false
        
        // 确保20项配置
        for i in 1...20 {
            let key = "WiFi_\(i)"
            if wifiConfig[key] == nil {
                wifiConfig[key] = [
                    "ssid": "WiFi_\(i)",
                    "password": randomPassword()
                ]
                updated = true
                log("已添加: \(key)")
            }
        }
        
        if updated {
            itlwm["WiFiConfig"] = wifiConfig
            personalities["itlwm"] = itlwm
            plist["IOKitPersonalities"] = personalities
        }
        
        return updated
    }
    
    private func parseWiFiConfigs(plist: [String: Any]) -> [WiFiConfig] {
        guard let personalities = plist["IOKitPersonalities"] as? [String: Any],
              let itlwm = personalities["itlwm"] as? [String: Any],
              let wifiConfig = itlwm["WiFiConfig"] as? [String: [String: String]] else {
            return []
        }
        
        return wifiConfig.map { key, value in
            WiFiConfig(
                key: key,
                ssid: value["ssid"] ?? "未知",
                password: value["password"] ?? ""
            )
        }
        .sorted { $0.key < $1.key }
    }
    
    private func reloadConfigs() {
        guard let kext = kextURL else { return }
        let plistURL = kext.appendingPathComponent("Contents/Info.plist")
        loadPlist(url: plistURL)
    }
    
    private func saveChanges() {
        guard let kext = kextURL else { return }
        let plistURL = kext.appendingPathComponent("Contents/Info.plist")
        
        isLoading = true
        Task {
            do {
                // 读取文件
                let data = try Data(contentsOf: plistURL)
                guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                    log("错误: 无法解析PLIST")
                    return
                }
                
                // 更新配置
                guard var personalities = plist["IOKitPersonalities"] as? [String: Any],
                      var itlwm = personalities["itlwm"] as? [String: Any],
                      var wifiConfig = itlwm["WiFiConfig"] as? [String: [String: String]] else {
                    log("错误: PLIST结构无效")
                    return
                }
                
                // 更新特定项
                wifiConfig[editingKey] = [
                    "ssid": editingSSID,
                    "password": editingPassword
                ]
                
                // 写回文件
                itlwm["WiFiConfig"] = wifiConfig
                personalities["itlwm"] = itlwm
                plist["IOKitPersonalities"] = personalities
                
                let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try newData.write(to: plistURL)
                
                // 更新UI
                if let index = wifiConfigs.firstIndex(where: { $0.key == editingKey }) {
                    wifiConfigs[index].ssid = editingSSID
                    wifiConfigs[index].password = editingPassword
                }
                
                log("已更新配置: \(editingKey)")
                log("新SSID: \(editingSSID)")
                
                await MainActor.run {
                    isLoading = false
                    showEditor = false
                }
            } catch {
                log("错误: \(error.localizedDescription)")
                isLoading = false
            }
        }
    }
    
    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        logs.insert("[\(timestamp)] \(message)", at: 0)
    }
    
    private func randomPassword() -> String {
        String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
    }
}

// MARK: - UI组件

// 配置行视图
struct ConfigRow: View {
    let config: WiFiConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(config.ssid)
                    .font(.headline)
                    .foregroundColor(isSelected ? .blue : .primary)
                
                Text("密码: \(config.password)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(config.key)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(CircleButtonStyle(color: .gray))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.05) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// 编辑器视图
struct EditorView: View {
    @Binding var ssid: String
    @Binding var password: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("编辑WiFi配置")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("WiFi名称")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("输入WiFi名称", text: $ssid)
                    .textFieldStyle(RoundedTextFieldStyle())
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SecureField("输入密码", text: $password)
                    .textFieldStyle(RoundedTextFieldStyle())
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("取消", action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                
                Button("保存", action: onSave)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .padding(.vertical)
        .frame(width: 400)
        .background(Color(.white))
        .cornerRadius(16)
    }
}

// 日志视图
struct LogView: View {
    @Binding var logs: [String]
    @State private var showClearAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("操作日志")
                    .font(.headline)
                Spacer()
                
                Button(action: { showClearAlert = true }) {
                    Text("清除")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .alert("确定要清除所有日志吗？", isPresented: $showClearAlert) {
                    Button("取消", role: .cancel) {}
                    Button("清除", role: .destructive) {
                        logs.removeAll()
                    }
                }
            }
            .padding()
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(logs, id: \.self) { log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.05))
                                )
                                .id(log)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if let last = logs.first {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - 按钮样式

struct CircleButtonStyle: ButtonStyle {
    var color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.blue)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.07))
            )
    }
}

#Preview {
    WithoutHeliPort()
}
