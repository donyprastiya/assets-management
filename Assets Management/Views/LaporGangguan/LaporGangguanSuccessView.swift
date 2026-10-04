//
//  LaporGangguanSuccessView.swift
//  Assets Management
//
//  Created by Dony on 10/08/25.
//

import SwiftUI

struct LaporGangguanSuccessView: View {
    // Ambil ViewRouter untuk kembali ke halaman utama
    @EnvironmentObject var viewRouter: ViewRouter
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Kustom
                HStack {
                    Text("Lapor Gangguan")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                Spacer()
                
                // Konten Sukses di Tengah
                VStack(spacing: 24) {
                    Image("ic_success")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                    
                    Text("Berhasil Melaporkan Gangguan")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Tombol Kembali ke Halaman Utama
                Button(action: {
                    // Gunakan ViewRouter untuk kembali ke halaman utama
                    dismiss()
                }) {
                    Text("Kembali ke Halaman Utama")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(hex: BaseEnv.baseColor))
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
#Preview {
    LaporGangguanSuccessView()
        .environmentObject(ViewRouter())
}
