//
//  ListServiceView.swift
//  Assets Management
//
//  Created by Dony on 29/08/25.
//

import SwiftUI

// MARK: - 1. Data Models
// Model untuk setiap item layanan, mirip dengan data class di Kotlin
struct ServiceItemList: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let category: String
    let iconName: String // Menggunakan nama aset gambar
    let allowedRoles: [String]
}

// Enum untuk membedakan tipe baris di dalam daftar, mirip dengan getItemViewType di Adapter
enum ListItem: Identifiable, Hashable {
    case header(String)
    case service(ServiceItemList)
    
    var id: String {
        switch self {
        case .header(let title):
            return "header_\(title)"
        case .service(let item):
            return "service_\(item.id)"
        }
    }
}

// MARK: - 2. ViewModel
@MainActor
class ListServiceViewModel: ObservableObject {
    @Published var displayList: [ListItem] = []
    @Published var searchQuery = ""
    @Published var selectedCategory: String? = nil
    
    private var masterList: [ServiceItemList] = []
    private var visibleListForUserRole: [ServiceItemList] = []
    
    init() {
        populateMasterList()
        filterListForUserRole()
        filterAndDisplayList()
    }
    
    // Memfilter daftar berdasarkan role pengguna saat pertama kali ViewModel dibuat
    private func filterListForUserRole() {
        guard let token = TokenService.shared.getAccessToken(),
              let decoded = TokenService.shared.decode(jwtToken: token) else {
            self.visibleListForUserRole = []
            return
        }
        
        let userRoles = decoded.data.roles.map { $0.name.lowercased() }
        
        self.visibleListForUserRole = masterList.filter { serviceItem in
            // Cek apakah ada irisan antara role pengguna dan role yang diizinkan
            !Set(userRoles).isDisjoint(with: Set(serviceItem.allowedRoles))
        }
    }
    
    // Fungsi utama untuk memfilter dan mengelompokkan daftar yang akan ditampilkan
    func filterAndDisplayList() {
        var filteredList = visibleListForUserRole
        
        // Filter berdasarkan kategori yang dipilih
        if let category = selectedCategory {
            filteredList = filteredList.filter { $0.category == category }
        }
        
        // Filter berdasarkan pencarian
        if !searchQuery.isEmpty {
            filteredList = filteredList.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.subtitle.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Kelompokkan hasil filter berdasarkan kategori
        let grouped = Dictionary(grouping: filteredList, by: { $0.category })
        
        var newDisplayList: [ListItem] = []
        
        // Urutkan kategori sesuai urutan di master list untuk konsistensi
        let sortedCategories = masterList.map { $0.category }.removingDuplicates()
        
        for category in sortedCategories {
            if let items = grouped[category], !items.isEmpty {
                newDisplayList.append(.header(category))
                items.forEach { newDisplayList.append(.service($0)) }
            }
        }
        
        self.displayList = newDisplayList
    }
    
    // Mengisi daftar master dengan semua layanan yang tersedia
    private func populateMasterList() {
        masterList = [
            ServiceItemList(id: 1, title: "Database Aset Proteksi Sistem", subtitle: "Cek Data aset sistem.", category: "Fasop", iconName: "ic_data", allowedRoles: ["admin", "engineer", "guest_1", "guest_2"]),
            ServiceItemList(id: 2, title: "Laporan Gangguan Peralatan Fasop", subtitle: "Catat masalah & gangguan peralatan", category: "Fasop", iconName: "ic_paper", allowedRoles: ["admin", "engineer", "guest_2"]),
            ServiceItemList(id: 3, title: "Maintenance Aset", subtitle: "Jadwalkan & lacak pemeliharaan rutin.", category: "Fasop", iconName: "ic_monitoring", allowedRoles: ["admin", "engineer"]),
            ServiceItemList(id: 4, title: "Monitoring Catu Daya Fasop", subtitle: "Detail lengkap daya fasop.", category: "Kinerja Up2b", iconName: "ic_speed", allowedRoles: ["admin", "engineer"]),
            ServiceItemList(id: 5, title: "Realtime Kesiapan Peralatan Fasop", subtitle: "Status fasop secara langsung.", category: "Operasi Sistem", iconName: "ic_speed", allowedRoles: ["admin", "engineer"]),
            ServiceItemList(id: 6, title: "Monitoring Frek Sistem", subtitle: "Cek kestabilan frekuensi sistem.", category: "K3L & Kam", iconName: "ic_monitoring", allowedRoles: ["admin", "engineer"])
        ]
    }
}

// MARK: - 3. Main View
struct ListServiceView: View {
    @StateObject private var viewModel = ListServiceViewModel()
    @Environment(\.dismiss) var dismiss
//    @EnvironmentObject var viewRouter: ViewRouter
    @State private var presentedDestination: FullScreenDestination?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Kustom
            HeaderViewLG(title: "Daftar Layanan", onBack: { dismiss() })
            
            // Konten Utama
            VStack(spacing: 16) {
                // Bilah Pencarian
                SearchBarLG(searchText: $viewModel.searchQuery)
                    .onChange(of: viewModel.searchQuery) { _ in
                        viewModel.filterAndDisplayList()
                    }
                
                // Tombol Filter Kategori
                CategoryFilterView(selectedCategory: $viewModel.selectedCategory)
                    .onChange(of: viewModel.selectedCategory) { _ in
                        viewModel.filterAndDisplayList()
                    }
                
                // Daftar Layanan
                ServiceListView(listItems: viewModel.displayList,presentedDestination: $presentedDestination)
                
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.white))
        .navigationBarHidden(true)
        
        .fullScreenCover(item: $presentedDestination) { destination in
            // Logika untuk menentukan view tujuan, mirip seperti di Assets_ManagementApp
            switch destination {
            case .databaseAset:
                NavigationView { DatabaseAsetView() }
            case .laporGangguan:
                NavigationView { LaporGangguanView() }
            case .listGangguan:
                NavigationView { ListGangguanView() }
            default:
                // Fallback jika ada tujuan yang belum di-handle
                Text("Tujuan \(String(describing: destination)) belum diimplementasikan.")
            }
        }
    }
}

// MARK: - 4. Helper Views

// Header kustom
struct HeaderViewLG: View {
    let title: String
    let onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
            }
            Spacer()
            Text(title)
            Spacer()
            // Placeholder untuk menyeimbangkan judul
            Button(action: {}) { Image(systemName: "arrow.left") }.opacity(0)
        }
        .font(.custom("Inter18pt-SemiBold", size: 16))
        .foregroundColor(.black)
        .padding()
        .background(Color.white.shadow(color: .black.opacity(0.1), radius: 1, y: 1))
    }
}

// Bilah Pencarian
struct SearchBarLG: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Cari Layanan", text: $searchText)
                .foregroundColor(.gray)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
    }
}

// Tombol Filter Kategori Horizontal
struct CategoryFilterView: View {
    @Binding var selectedCategory: String?
    private let categories = ["Fasop", "Kinerja Up2b", "Operasi Sistem", "K3L & Kam"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        if selectedCategory == category {
                            selectedCategory = nil // Batal pilih
                        } else {
                            selectedCategory = category
                        }
                    }) {
                        Text(category)
                            .font(.custom("Inter18pt-Medium", size: 14))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color(hex: "#205781") : Color.white)
                            .foregroundColor(selectedCategory == category ? .white : .black)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
}

// Daftar Layanan dengan Header
struct ServiceListView: View {
    let listItems: [ListItem]
    @Binding var presentedDestination: FullScreenDestination?
    
    var body: some View {
        List {
            ForEach(listItems) { item in
                switch item {
                case .header(let title):
                    Section(header: Text(title)
                        .font(.custom("Inter18pt-Medium", size: 14))
                        .foregroundColor(Color(.gray))
                    ) {
                        EmptyView() // Section memerlukan konten
                    }
                case .service(let serviceItem):
                    Button(action: {
                        // 5. GANTI AKSI TOMBOL
                        // Tidak lagi memanggil viewRouter, tapi MENGATUR BINDING.
                        if let destination = destination(for: serviceItem) {
                            self.presentedDestination = destination
                        } else {
                            print("Tujuan untuk item ini belum diimplementasikan.")
                        }
                    }) {
                        ServiceListItemRow(item: serviceItem)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
    
    // [PERBAIKAN] Fungsi ini sekarang mengembalikan tujuan untuk router, bukan View
    private func destination(for item: ServiceItemList) -> FullScreenDestination? {
        switch item.id {
        case 1: return .databaseAset
        case 2: return .laporGangguan
        case 3: return .listGangguan
        // Untuk item lain yang belum ada tujuannya, kita kembalikan nil
        default: return nil
        }
    }
}


// Tampilan untuk satu baris item layanan
struct ServiceListItemRow: View {
    let item: ServiceItemList
    
    var body: some View {
        HStack(spacing: 16) {
            Image(item.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .padding(10)
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .foregroundColor(.black)
                Text(item.subtitle)
                    .font(.custom("Inter18pt-Regular", size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .background(Color.white)
        .cornerRadius(12)
    }
}


// MARK: - Preview
#Preview {
    NavigationView {
        ListServiceView()
            .environmentObject(ViewRouter())
    }
}

// MARK: - Helper Extension
// Untuk menghapus duplikat dari array (digunakan untuk kategori)
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
}
