//
//  CCToolBoxApp.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI

@main
struct CCToolBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        WindowGroup(id: "FixSleep"){
            FixSleep()
        }
        WindowGroup(id: "MountEFI"){
            MountEFI()
        }
        WindowGroup(id: "WithOutHeliPort"){
            WithoutHeliPort()
        }
        WindowGroup(id: "CPUFTool"){
            CPUFTool()
        }
    }
}
