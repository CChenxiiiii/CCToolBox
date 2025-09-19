//
//  ContentView.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI

enum AppPage: String, Identifiable, CaseIterable {
    case home, toolkits
    var id: String { self.rawValue }
    
    // 每个界面的标题
    var title: String {
        switch self {
        case .home: return "首页"
        case .toolkits: return "工具"
        }
    }
    var imageName: String {
        switch self {
        case .home: return "house.fill"
        case .toolkits: return "wrench.and.screwdriver.fill"
        }
    }
}

struct ContentView : View {
    @State private var selectedPage: AppPage? = .home
    let tabItems: [AppPage] = AppPage.allCases
    
    @ViewBuilder
    func currentPageView(_ page: AppPage) -> some View {
        switch page {
        case .home:
            HomePage() // 直接返回视图，而不是用 Group 包裹
        case .toolkits:
            ToolkitsView() // 直接返回视图
        }
    }
    
    var body: some View {
        if #available(macOS 15.0, *) {
            TabView(){
                Tab("首页",systemImage: "house.fill"){
                    HomePage()
                }
                Tab("工具",systemImage: "wrench.and.screwdriver.fill"){
                    ToolkitsView()
                }
            }
        } else {
            TabView(selection: $selectedPage) {
                ForEach(tabItems, id: \.self) { page in
                    currentPageView(page)
                        .tabItem {
                            Label(page.title, systemImage: page.imageName)
                        }
                        .tag(page)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 900,height: 500)
}
