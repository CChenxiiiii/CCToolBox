//
//  ToolkitView.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI

enum ToolAppPage: String, Identifiable, CaseIterable {
    case fixsleep, mountefi, itlwmconfig, cpuftool
    var id: String { self.rawValue }
    
    // 每个界面的标题
    var title: String {
        switch self {
        case .fixsleep: return "修复睡眠"
        case .mountefi: return "挂载EFI"
        case .itlwmconfig: return "摆脱HeliPort(itlwm自动化)"
        case .cpuftool : return "修复睿频电源管理"
        }
    }
    var imageName: String {
        switch self {
        case .fixsleep: return "zzz"
        case .mountefi: return "externaldrive"
        case .itlwmconfig: return "wifi"
        case .cpuftool: return "cpu.fill"
        }
    }
}

struct ToolkitsView: View {
    @State private var selectedPage: ToolAppPage? = .fixsleep
    
    @ViewBuilder
        func currentToolPageView(_ page: ToolAppPage) -> some View {
            switch page {
            case .fixsleep:
                ToolStartPage(imageName: "moon.fill", title1: "修复睡眠", author: "CChenxiiiii", descri: "用于简易地修复睡眠，为通用程序，部分机型可能需要微调。在程序运行结束后有说明", laug: "SwiftUI 100%", windowID: "FixSleep")
            case .mountefi:
                ToolStartPage(imageName: "externaldrive.fill.badge.plus", title1: "挂载硬盘", author: "CChenxiiiii", descri: "用于挂载EFI分区，默认挂载diskXs1", laug: "SwiftUI 100%", windowID: "MountEFI")
            case .itlwmconfig:
                ToolStartPage(imageName: "wifi", title1: "摆脱HeliPort(itlwm自动化)", author: "CChenxiiiii 功能参考Win10Q", descri: "可以离开HeliPort了！一劳永逸哦。\n注：在选择kext时，可以右键然后选择Quick Look(预览)就选择了文件了", laug: "Swift 100%", windowID: "WithOutHeliPort")
            case .cpuftool:
                ToolStartPage(imageName: "cpu.fill", title1: "修复睿频电源管理", author: "CChenxiiiii", descri: "修复Intel的Haswell及以上的睿频异常问题", laug: "Swift 100%", windowID: "CPUFTool")
            }
        }
    var body: some View {
        if #available(macOS 15.0, *){
            TabView{
                Tab("修复睡眠",systemImage: "zzz"){
                    ToolStartPage(imageName: "moon.fill", title1: "修复睡眠", author: "CChenxiiiii", descri: "用于简易地修复睡眠，为通用程序，部分机型可能需要微调。在程序运行结束后有说明", laug: "SwiftUI 100%", windowID: "FixSleep")
                }
                Tab("挂载硬盘",systemImage: "externaldrive"){
                    ToolStartPage(imageName: "externaldrive.fill.badge.plus", title1: "挂载硬盘", author: "CChenxiiiii", descri: "用于挂载EFI分区，默认挂载diskXs1", laug: "SwiftUI 100%", windowID: "MountEFI")
                }
                Tab("摆脱HeliPort(itlwm自动化)",systemImage: "wifi") {
                    ToolStartPage(imageName: "wifi", title1: "摆脱HeliPort(itlwm自动化)", author: "CChenxiiiii 功能参考Win10Q", descri: "可以离开HeliPort了！一劳永逸哦。\n注：在选择kext时，可以右键然后选择Quick Look(预览)就选择了文件了", laug: "Swift 100%", windowID: "WithOutHeliPort")
                }
                Tab("修复睿频电源管理",systemImage: "cpu.fill") {
                    ToolStartPage(imageName: "cpu.fill", title1: "修复睿频电源管理", author: "CChenxiiiii", descri: "修复Intel的Haswell及以上的睿频异常问题", laug: "Swift 100%", windowID: "CPUFTool")
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else{
            NavigationSplitView {
                List(ToolAppPage.allCases, selection: $selectedPage) { page in
                    Text(page.title).tag(page)
                }
            } detail: {
                if let selectedPage {
                    currentToolPageView(selectedPage) // 动态返回对应视图
                } else {
                    Text("Select a page")
                }
            }
        }
    }
}

#Preview {
    ToolkitsView()
        .frame(width: 800, height: 500)
}
