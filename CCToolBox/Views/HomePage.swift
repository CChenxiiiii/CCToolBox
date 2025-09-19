//
//  HomePage.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI
import DeviceKit

struct HomePage: View {
    let device = Device.current
    var body: some View {
        VStack(spacing: 12) {
            VStack {
                Text("OpenCore Toolkits")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                Text("By CChenxiiiii")
                    .fontWeight(.light)
            }
            VStack(alignment: .center,spacing: 20){
                Image(systemName: macIconName())
                    .font(.system(size: 90))
                HStack(spacing: 50) {
                    VStack(alignment: .leading,spacing: 10) {
                        Text("设备型号：")
                        Text("处理器：")
                        Text("图形卡：")
                        Text("内存条：")
                        Text("序列号：")
                    }
                    VStack(alignment: .leading,spacing: 10) {
                        DeviceInfoView()
                        CPUInfoView()
                        AllGPUView()
                        MemoryInfoView()
                        Text(serialNumber())
                    }
                }
                HStack(spacing: 40) {
                    InfoBox(title: "macOS版本", value: "\(macOSPrettyString())", icon: "desktopcomputer")
                    Image("OpenCore-Toolkits")
                        .resizable()
                        .frame(width: 110,height: 110)
                    InfoBox(title: "存储空间", value: "\(diskSpaceString())", icon: "externaldrive")
                }
            }
        }
    }
}

#Preview {
    HomePage()
        .frame(width: 800,height: 500)
}











struct DeviceInfoView: View {
    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading) {
                Text(friendlyMacName()+"     "+rawModelIdentifier())
            }
        }
    }
}

struct CPUInfoView: View {
    @State private var cpu = currentCPUInfo()

    var body: some View {
        Text("\(cpu.model)")
    }
}

public struct AllGPUView: View {
    private var gpus: [GPUInfo] { GPUReader.read() }
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(gpus) { gpu in
                Text(gpu.name+" \(gpu.memoryGB) GB")
            }
        }
    }
}

public struct MemoryInfoView: View {
    private var memory: MemoryInfo = MemoryReader.read()
    public init() {}

    public var body: some View {
        HStack {
            Text("\(memory.capacityGB) GB Memory")
        }
    }
}
