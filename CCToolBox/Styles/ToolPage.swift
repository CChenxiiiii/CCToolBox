//
//  ToolPage.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI

struct ToolPage : View {
    
    let ImageName : String
    let Title1 : String
    let Author : String
    let Descri : String
    let Laug : String
    
    init(ImageName: String, Title1: String, Author: String, Descri: String, Laug: String) {
        self.ImageName = ImageName
        self.Title1 = Title1
        self.Author = Author
        self.Descri = Descri
        self.Laug = Laug
    }
    
    var body: some View{
        VStack(spacing : 30) {
            VStack(spacing : 10) {
                Image(systemName: ImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128,height: 128)
                    
                VStack(spacing : 5) {
                    Text(Title1)
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("By \(Author)          语言：\(Laug)")
                        .font(.caption)
                }
            }
            Text(Descri)
                .font(.system(size: 14))
        }
    }
}


struct ToolStartPage: View {
    
    let imageName : String
    let title1 : String
    let author : String
    let descri : String
    let laug : String
    let windowID : String
    
    init(imageName: String, title1: String, author: String, descri: String, laug: String, windowID: String) {
        self.imageName = imageName
        self.title1 = title1
        self.author = author
        self.descri = descri
        self.laug = laug
        self.windowID = windowID
    }
    
    @Environment(\.openWindow) private var openWindow
    var body: some View{
        VStack(spacing: 30) {
            ToolPage(ImageName: imageName, Title1: title1, Author: author, Descri: descri, Laug: laug)
            if #available(macOS 26.0, *) {
                Button(action: {
                    openWindow(id: windowID)
                }) {
                    Text("启动工具🔧")
                        .font(.title2)
                        .padding()
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 25))
                .cornerRadius(25)
            } else {
                Button(action: {
                    openWindow(id: windowID)
                }) {
                    Text("启动工具🔧")
                        .font(.title2)
                        .padding()
                }
            }
        }
    }
}
