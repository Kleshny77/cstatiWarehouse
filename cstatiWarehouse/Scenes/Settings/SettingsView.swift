//
//  SettingsView.swift
//  cstatiWarehouse
//
//  Created by Артём on 27.03.2026.
//

import SwiftUI
// имя аватарка имейл
struct SettingsView: View {
    var body: some View {
        VStack {
            profile
//            bunner
            settings
        }
        .padding(.top, 20)
    }
    
    var profile: some View {
        VStack {
            HStack {
                Text("Профиль")
                    .foregroundStyle(.black.opacity(0.9))
                    .font(font: .bold, size: 34)
                
                Spacer()
                
                Button {
                    
                } label: {
                    Image(systemName: "bell.badge")
                }
                
            }
            .padding(.horizontal, 20)
            
        }
    }
    
//    var bunner: some View {
//        VStack {
//            HStack {
//                Text("добавьте организацию")
//                
//                Spacer()
//                
//                Image(systemName: "phone")
//            }
//            .padding(.horizontal, 20)
//        }
//        .background(.red)
//        .padding(.horizontal, 20)
//    }
    var settings: some View {
        List {
            Section("some") {
                NavigationLink("Notifications") { Text("fdaf") }
            }
        }
    }
}

#Preview() {
    SettingsView()
}
