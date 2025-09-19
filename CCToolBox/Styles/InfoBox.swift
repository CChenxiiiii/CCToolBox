//
//  InfoBox.swift
//  CCToolBox
//
//  Created by chenxi on 2025/8/6.
//

import SwiftUI

struct InfoBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        if #available(macOS 26.0, *) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(15)
            .frame(width: 120)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(15)
            .frame(width: 120)
        }
    }
}
