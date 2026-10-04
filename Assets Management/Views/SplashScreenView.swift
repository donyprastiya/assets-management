//
//  SplashScreenView.swift
//  Assets Management
//
//  Created by Dony on 01/07/25.
//

import SwiftUI

struct SplashScreenView: View {
    
    var body: some View {
        // ZStack digunakan untuk menumpuk view.
        // Sangat bagus untuk membuat background dan menaruh konten di tengahnya.
        ZStack {
            // Latar belakang splash screen
            Color(hex: BaseEnv.baseColor) // Warna biru gelap
                .ignoresSafeArea() // Penuhi seluruh layar

            // Konten di tengah
            VStack {
                // Gunakan logo Anda di sini.
                // Untuk contoh, kita pakai SF Symbol dari Apple.
                Image("ic_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .foregroundColor(.white)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Ini untuk melihat preview di Xcode Canvas
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}

