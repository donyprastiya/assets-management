//
//  LaporGangguanHistoryView.swift
//  Assets Management
//
//  Created by Dony on 23/08/25.
//

import SwiftUI

// MARK: - 1. Data Models
// Model untuk menampung data riwayat dari API
struct MaintenanceHistoryItem: Identifiable {
    let id = UUID()
    let date: String
    let status: String
    let description: String
}

// MARK: - 2. ViewModel
@MainActor
class LaporGangguanHistoryViewModel: ObservableObject {
    @Published var historyItems: [MaintenanceTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// [PERBAIKAN] Fungsi ini sekarang mengambil data riwayat dari server.
    func fetchHistory() async {
        isLoading = true
        errorMessage = nil
        
        // Ambil tipe dan nilai dari storage yang disimpan oleh scanner
        let type = Storage.getString(forKey: "lastScannedType") ?? "serial_number"
        let value = Storage.getString(forKey: "lastScannedValue") ?? ""
        
        guard !value.isEmpty else {
            errorMessage = "Tidak ada data aset yang ditemukan untuk melihat riwayat."
            isLoading = false
            return
        }
        
        let urlString = "\(BaseEnv.baseURL)/maintenance/get_task_list_by_qr?type=\(type)&value=\(value)"
        guard let url = URL(string: urlString) else {
            errorMessage = "URL tidak valid."
            isLoading = false
            return
        }
        
        guard let token = await AuthenticationService.shared.getValidAccessToken() else {
            errorMessage = "Sesi tidak valid."
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decodedResponse = try JSONDecoder().decode(TaskListResponse.self, from: data)
            
            if decodedResponse.success {
                self.historyItems = decodedResponse.data
            } else {
                errorMessage = "Gagal mengambil riwayat."
            }
            
        } catch {
            errorMessage = "Terjadi kesalahan: \(error.localizedDescription)"
            print("Gagal mengambil riwayat maintenance: \(error)")
        }
        
        isLoading = false
    }
}
// MARK: - 3. Main View
struct LaporGangguanHistoryView: View {
    
    @StateObject private var viewModel = LaporGangguanHistoryViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(.white).ignoresSafeArea()
            VStack(spacing: 0) {
                // Header Kustom
                HStack {
                    // Tombol untuk menutup bottom sheet
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    
                    Spacer() // Mendorong judul ke tengah
                    
                    Text("Lapor Gangguan")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.black)
                    
                    Spacer() // Menjaga agar judul tetap di tengah
                    
                    // Menambahkan view kosong agar spacer berfungsi dengan benar
                    // dan tombol kembali tidak mempengaruhi posisi tengah judul.
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .opacity(0) // Dibuat tidak terlihat
                }
                .padding(.vertical, 12)

                // Konten Riwayat
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            ForEach(viewModel.historyItems) { item in
                                HistoryRowView(item: item)
                                if item.id != viewModel.historyItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await viewModel.fetchHistory()
            }
        }
    }
}

// MARK: - 4. Helper Views

struct HistoryRowView: View {
    let item: MaintenanceTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Menampilkan tanggal dari API
            Text(item.updatedAt ?? "")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)
            
            // Menampilkan status dari API
            Text(item.currentStatus ?? "")
                .font(.custom("Inter18pt-Medium", size: 16))
                .foregroundColor(.black)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        LaporGangguanHistoryView()
    }
}
