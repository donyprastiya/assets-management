//
//  ListGangguanView.swift
//  Assets Management
//
//  Created by Dony on 24/08/25.
//

import SwiftUI

enum MaintenanceStatus: Int, CaseIterable, Identifiable {
    case draft = 1
    case inProgress = 2
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        }
    }
}

@MainActor
class ListGangguanViewModel: ObservableObject {
    @Published var maintenanceItems: [MaintenanceTaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // [PERUBAHAN] Properti untuk mengelola state filter dan paginasi
    @Published var selectedStatus: MaintenanceStatus? = nil
    var currentPage = 1
    var canLoadMorePages = true
    let itemsPerPage = 10
    
    func fetchMaintenanceList() async {
        guard !isLoading && canLoadMorePages else { return }
        
        // Hanya tampilkan loading besar untuk halaman pertama
        if currentPage == 1 {
            isLoading = true
            errorMessage = nil
        }
        
        var urlString = "\(BaseEnv.baseURL)/maintenance/index?page=\(currentPage)&per_page=\(itemsPerPage)"
        
        // [PERUBAHAN] Tambahkan parameter status ke URL jika ada yang dipilih
        if let status = selectedStatus {
            urlString += "&status=\(status.rawValue)"
        }
        
        guard let url = URL(string: urlString) else {
            errorMessage = "URL tidak valid."; isLoading = false; return
        }
        
        guard let token = await AuthenticationService.shared.getValidAccessToken() else {
            errorMessage = "Sesi tidak valid."; isLoading = false; return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decodedResponse = try JSONDecoder().decode(MaintenanceListResponse.self, from: data)
            
            if decodedResponse.success {
                self.maintenanceItems.append(contentsOf: decodedResponse.data.tasks)
                
                if decodedResponse.data.tasks.count < itemsPerPage {
                    self.canLoadMorePages = false
                } else {
                    self.currentPage += 1
                }
            } else {
                errorMessage = "Gagal mengambil daftar maintenance."
            }
            
        } catch {
            errorMessage = "Terjadi kesalahan: \(error.localizedDescription)"
            print("Gagal mengambil daftar maintenance: \(error)")
        }
        
        isLoading = false
    }
    
    /// Fungsi untuk me-reset state dan memuat ulang dari awal
    private func resetAndFetch() {
        // Reset state paginasi dan data
        currentPage = 1
        canLoadMorePages = true
        maintenanceItems = []
        
        // Panggil fungsi fetch utama sebagai Task baru
        Task {
            await fetchMaintenanceList()
        }
    }
    
    /// Fungsi yang dipanggil oleh View saat filter berubah
    func filterDidChange() {
        resetAndFetch()
    }
    
    /// Fungsi yang dipanggil oleh View untuk pull-to-refresh
    func refreshList() async {
        // Saat refresh, kita tidak mengubah filter yang ada, hanya memuat ulang dari awal.
        currentPage = 1
        canLoadMorePages = true
        maintenanceItems = []
        await fetchMaintenanceList()
    }
}

// MARK: - 3. Main View
struct ListGangguanView: View {
    
    @StateObject private var viewModel = ListGangguanViewModel()
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
                    
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .opacity(0) // Dibuat tidak terlihat
                }
                .padding(.vertical, 12)

                FilterButtonsView(selectedStatus: $viewModel.selectedStatus)
                    .padding(.horizontal)
                    .padding(.bottom)

                // Konten Daftar
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12){
                        Image("ic_warning")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .padding(.horizontal)
                        Text(errorMessage)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.maintenanceItems) { item in
                                MaintenanceListItemView(item: item)
                            }
                            if viewModel.canLoadMorePages {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await viewModel.fetchMaintenanceList()
                                        }
                                    }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshList()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await viewModel.fetchMaintenanceList()
            }
        }
        .onChange(of: viewModel.selectedStatus) { _ in
            viewModel.filterDidChange()
        }
    }
}

struct FilterButtonsView: View {
    @Binding var selectedStatus: MaintenanceStatus?
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(MaintenanceStatus.allCases) { status in
                Button(action: {
                    if selectedStatus == status {
                        selectedStatus = nil // Batal pilih jika tombol yang sama ditekan
                    } else {
                        selectedStatus = status
                    }
                }) {
                    Text(status.displayName)
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(selectedStatus == status ? Color(hex: BaseEnv.baseColor) : Color.white)
                        .foregroundColor(selectedStatus == status ? .white : .black)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: BaseEnv.baseColor), lineWidth: 1)
                        )
                }
            }
        }
    }
}

struct MaintenanceListItemView: View {
    let item: MaintenanceTaskItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Baris atas: Nama dan Tanggal
            HStack {
                Text(item.assetName)
                    .font(.custom("Inter18pt-Bold", size: 14))
                    .foregroundColor(.black)
                Spacer()
                Text(item.updatedAt.prefix(10))
                    .font(.custom("Inter18pt-Regular", size: 12))
                    .foregroundColor(.black)
            }
            
            // Baris tengah: Serial Number dan Status
            HStack {
                Text(item.techidentno)
                    .font(.custom("Inter18pt-Regular", size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange) // Warna bisa disesuaikan dengan status
                        .frame(width: 8, height: 8)
                    Text(item.currentStatus)
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Text(item.directoryFullName)
                .font(.custom("Inter18pt-Regular", size: 12))
                .foregroundColor(.black)
            
            // Baris bawah: Deskripsi
            Text(item.latestLog?.notes ?? "Tidak ada catatan.")
                .font(.custom("Inter18pt-Regular", size: 12))
                .foregroundColor(.black)
        }
        .background(Color.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 0.5)
        )
    }
}


// MARK: - Preview
#Preview {
    NavigationView {
        ListGangguanView()
    }
}
