//
//  LaporGangguanResultView.swift
//  Assets Management
//
//  Created by Dony on 02/08/25.
//

import SwiftUI
import PhotosUI
import CoreLocation
import Combine

// MARK: - 1. Data Models
// Model untuk item gambar yang di-upload
struct UploadedImageItem: Identifiable, Equatable {
    let id = UUID()
    let image: Image      // Untuk pratinjau di UI
    let fileUrl: String   // URL dari server
    let fileName: String
    
    static func == (lhs: UploadedImageItem, rhs: UploadedImageItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 2. ViewModel
@MainActor
class LaporGangguanResultViewModel: ObservableObject {
    
    @Published var serialNumber: String = ""
    @Published var assetName: String = ""
    @Published var categoryName: String = ""
    @Published var directoryName: String = ""
    @Published var isManualEntry: Bool = false
    
    //Pickers
    @Published var selectedPIC: PICSelection?
    @Published var selectedCategory: CategorySelection?
    @Published var selectedDirectory: DirectorySelection?
    
    @Published var notes: String = ""
    @Published var uploadedImages: [UploadedImageItem] = []
    
    @Published var picOptions: [PICSelection] = []
    @Published var categoryOptions: [CategorySelection] = []
    @Published var directoryOptions: [DirectorySelection] = []
    
    // State untuk proses
    @Published var isSubmitting = false
    @Published var isLoadingCategories = false
    @Published var isLoadingPICs = false
    @Published var isLoadingDirectories = false
    
    @Published var hasMaintenanceHistory = false
    
    /// Memuat data awal dari StorageService
    func loadInitialData() {
        // Cek flag 'isManual' dari storage
        let isManualFlag = Storage.getString(forKey: "isManual") ?? "0"
        self.isManualEntry = isManualFlag == "1"
        
        if self.isManualEntry {
            // Jika manual, kosongkan field dan hapus flag
            self.assetName = ""
            self.categoryName = ""
            self.selectedCategory = categoryOptions.first
            Storage.removeData(forKey: "isManual")
            Storage.removeData(forKey: "laporGangguan_categoryName")
            Storage.removeData(forKey: "laporGangguan_directoryName")
            Storage.saveString("-", forKey: "laporGangguan_serialNumber")
        } else {
            // Jika dari scan, muat data seperti biasa
            self.assetName = Storage.getString(forKey: "laporGangguan_name") ?? "Tidak Ditemukan"
            let storedCategory = Storage.getString(forKey: "laporGangguan_categoryName") ?? "Tidak Ditemukan"
            self.categoryName = storedCategory
            self.directoryName = Storage.getString(forKey: "laporGangguan_directoryName") ?? "Tidak Ditemukan"
        }
    }
    
    func fetchDirectories() async {
        isLoadingDirectories = true
        let urlString = "\(BaseEnv.baseURL)/maintenance/leaf_directory"
        guard let url = URL(string: urlString) else { return }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DirectoryResponse.self, from: data)
            if response.success {
                self.directoryOptions = response.data
            }
        } catch {
            print("Gagal mengambil daftar direktori: \(error)")
        }
        isLoadingDirectories = false
    }
    
    func fetchAllCategories() async {
        isLoadingCategories = true
        let urlString = "\(BaseEnv.baseURL)/asset/get_all_categories"
        guard let url = URL(string: urlString) else { return }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let categories = try JSONDecoder().decode([CategorySelection].self, from: data)
            self.categoryOptions = categories
            
            // Coba atur nilai default picker berdasarkan nama kategori yang disimpan
            if let initialCategory = categories.first(where: { $0.name == self.categoryName }) {
                self.selectedCategory = initialCategory
            }
        } catch {
            print("Gagal mengambil daftar kategori: \(error)")
        }
        isLoadingCategories = false
    }
    
    func fetchPICs() async {
        isLoadingPICs = true
        let urlString = "\(BaseEnv.baseURL)/maintenance/get_flows_assign_person"
        guard let url = URL(string: urlString) else { return }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(PICResponse.self, from: data)
            
            // Buat daftar PICSelection yang berisi kedua ID
            let allSelections = response.data.flatMap { flow -> [PICSelection] in
                return flow.userList.flatMap { userList -> [PICSelection] in
                    // Langsung akses objek 'role' karena bukan lagi array
                    let role = userList.role
                    
                    // Kemudian, petakan setiap pengguna (user)
                    return userList.users.map { user -> PICSelection in
                        // Buat PICSelection dengan flowId dari role.id, sesuai permintaan
                        PICSelection(flowId: role.id, userId: user.id, userName: user.name)
                    }
                }
            }
            self.picOptions = allSelections
            
        } catch {
            print("Gagal mengambil daftar PIC: \(error)")
        }
        isLoadingPICs = false
    }
    
    func addImage(uiImage: UIImage, fileName: String, fileUrl: String) {
        let newImage = UploadedImageItem(
            image: Image(uiImage: uiImage),
            fileUrl: fileUrl, // <-- Gunakan URL dari server
            fileName: fileName
        )
        uploadedImages.append(newImage)
    }
    
    func deleteUploadedTempFiles() async {
        let fileNames = self.uploadedImages.map { $0.fileName }
        
        print("Menghapus file sementara: \(fileNames)")
        
        let urlString = "\(BaseEnv.baseURL)/maintenance/delete_temp_files"
        guard let url = URL(string: urlString) else { return }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeleteFilesRequest(files: fileNames)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // [DITAMBAHKAN] Cetak respons mentah
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- RAW DELETE RESPONSE ---\n\(jsonString)\n-------------------------")
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Berhasil menghapus file sementara dari server.")
            } else {
                print("Gagal menghapus file sementara dari server.")
            }
        } catch {
            print("Error saat menghapus file sementara: \(error)")
        }
    }
    
    func submitLaporan() async throws {
        isSubmitting = true
        defer { isSubmitting = false }
        
        // 2. Siapkan data untuk request body
        let assetID = isManualEntry ? "0" : (Storage.getString(forKey: "laporGangguan_assetId") ?? "0")
        let categoryIDString = isManualEntry ? (selectedCategory?.id ?? "0") : (Storage.getString(forKey: "laporGangguan_categoryId") ?? "0")
        let directoryIDString = isManualEntry ? (selectedDirectory?.id ?? "0") : (Storage.getString(forKey: "laporGangguan_directoryId") ?? "0")
        let newAssetName = isManualEntry ? assetName : (Storage.getString(forKey: "laporGangguan_name") ?? "0")
        
        var picDictionary: [String: [Int]] = [:]
        if let selectedPIC = selectedPIC, let picIdInt = Int(selectedPIC.userId) {
            picDictionary[selectedPIC.flowId] = [picIdInt]
        }
        
        let uploadedFileURLs = self.uploadedImages.map { $0.fileUrl }
        // Cetak daftar URL tersebut
        print("Uploaded File URLs: \(uploadedFileURLs)")
        
        // 3. Buat request body
        let requestBody = SubmitLaporanRequest(
            assetId: assetID,
            newAssetName: newAssetName,
            newAssetCategory: Int(categoryIDString) ?? 0,
            newAssetDirectory: Int(directoryIDString) ?? 0,
            note: notes,
            uploadedFiles: uploadedFileURLs,
            pic: picDictionary
        )
        
        print("Request: \(requestBody)")
        
        // 4. Lakukan panggilan API
        let urlString = "\(BaseEnv.baseURL)/maintenance/create"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { throw URLError(.userAuthenticationRequired) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("--- RAW JSON RESPONSE ---\n\(jsonString)\n-------------------------")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            // Coba decode pesan error dari server
            if let errorResponse = try? JSONDecoder().decode(SubmitLaporanErrorResponse.self, from: data) {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])
            } else {
                // Jika format error tidak dikenali, lempar error umum
                throw URLError(.badServerResponse)
            }
        }
        
        let decodedResponse = try JSONDecoder().decode(SubmitLaporanResponse.self, from: data)
        if !decodedResponse.success {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: decodedResponse.message])
        }
        
        
        print("Laporan berhasil dikirim: \(decodedResponse.message)")
    }
    
    func checkMaintenanceHistory(type: String, value: String) async {
        let urlString = "\(BaseEnv.baseURL)/maintenance/get_task_list_by_qr?type=\(type)&value=\(value)"
        guard let url = URL(string: urlString) else { return }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TaskListResponse.self, from: data)
            // Tombol akan muncul jika success == true DAN data tidak kosong
            self.hasMaintenanceHistory = response.success && !response.data.isEmpty
        } catch {
            print("Gagal mengecek riwayat maintenance: \(error)")
            self.hasMaintenanceHistory = false
        }
    }

}

// MARK: - 3. Main View
struct LaporGangguanResultView: View {
    
    @StateObject private var viewModel = LaporGangguanResultViewModel()
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showImagePreview = false
    @State private var isProcessingImage = false
    
    @State private var showConfirmationSheet = false
    @State private var showCancelConfirmationSheet = false
    
    @State private var showSuccessSheet = false
    
    @State private var showValidationErrorAlert = false
    @State private var isShowingDirectorySheet = false
    
    var body: some View {
        ZStack {
            Color(.white).ignoresSafeArea()
            VStack(spacing: 0) {
                // Header Kustom
                HStack {
                    // Tombol untuk menutup bottom sheet
                    Button(action: {
                        showCancelConfirmationSheet = true
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
                
                // Form Konten
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Detail Asset")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(.black)
                        
                        // Detail Aset (Read-only dan Picker)
                        if viewModel.isManualEntry {
                            EditableInfoRow(label: "Nama Aset", text: $viewModel.assetName)
                        } else {
                            InfoRow(label: "Nama Aset", value: viewModel.assetName)
                        }
                        
                        if viewModel.isManualEntry {
                            PickerRowDynamic(
                                label: "Kategori",
                                selection: $viewModel.selectedCategory,
                                options: viewModel.categoryOptions,
                                isLoading: viewModel.isLoadingCategories
                            )
                            PickerRowDirectory(
                                label: "Direktori",
                                selection: viewModel.selectedDirectory,
                                isLoading: viewModel.isLoadingDirectories,
                                isPresented: $isShowingDirectorySheet // <-- Binding baru
                            )
                        } else {
                            InfoRow(label: "Kategori", value: viewModel.categoryName)
                            InfoRow(label: "Direktori", value: viewModel.directoryName)
                        }
                        
                        PickerRowPIC(
                            label: "Pilih PIC",
                            selection: $viewModel.selectedPIC,
                            options: viewModel.picOptions,
                            isLoading: viewModel.isLoadingPICs
                        )
                        
                        // Catatan Awal
                        NoteEditor(label: "Catatan Awal", text: $viewModel.notes)
                        
                        ImageUploadSection(images: $viewModel.uploadedImages, showCamera: $showCamera)
                        
                        if !viewModel.isManualEntry && viewModel.hasMaintenanceHistory{
                            NavigationLink(destination: LaporGangguanHistoryView()) {
                                HStack {
                                    Text("Maintenance History")
                                    Spacer()
                                    Image("ic_arrowblue")
                                }
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(Color(hex: "#205781"))
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
                
                // Tombol Submit
                Button(action: {
                    showConfirmationSheet = true
                    
                }) {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Submit Laporan")
                    }
                }
                .font(.custom("Inter18pt-SemiBold", size: 14))
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(Color(hex: BaseEnv.baseColor))
                .cornerRadius(10)
                .disabled(viewModel.isSubmitting)
            }
            .padding(.horizontal, 16)
            if isProcessingImage {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("Memproses Gambar...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadInitialData()
            Task {
                await viewModel.fetchAllCategories()
                await viewModel.fetchPICs()
                await viewModel.fetchDirectories()
                
                if !viewModel.isManualEntry {
                    let type = "serial_number"
                    let value = Storage.getString(forKey: "laporGangguan_serialNumber") ?? ""
                    await viewModel.checkMaintenanceHistory(type: type, value: value)
                }
            }
        }
        .sheet(isPresented: $isShowingDirectorySheet) {
            DirectorySearchView(allDirectories: viewModel.directoryOptions) { selectedDirectory in
                viewModel.selectedDirectory = selectedDirectory
            }
        }
        .sheet(isPresented: $showCamera, onDismiss: {
            if let originalImage = capturedImage {
                isProcessingImage = true // Tampilkan ProgressView
                Task {
                    // Proses gambar di background thread
                    let processedImage = processImage(originalImage)
                    capturedImage = processedImage // Update state dengan gambar yang sudah diproses
                    isProcessingImage = false // Sembunyikan ProgressView
                    showImagePreview = true // Tampilkan pratinjau
                }
            }
        }) {
            ImagePicker(selectedImage: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        // [BARU] Sheet untuk menampilkan pratinjau gambar
        .sheet(isPresented: $showImagePreview) {
            if let imageToPreview = capturedImage {
                // Panggil LaporGangguanPreviewView dengan onSave yang benar
                LaporGangguanPreviewView(image: imageToPreview, onSave: { fileName, fileUrl in
                    // Aksi ini dijalankan saat "Gunakan Foto" ditekan
                    
                    // Panggil fungsi addImage yang baru dengan data dari server
                    viewModel.addImage(uiImage: imageToPreview, fileName: fileName, fileUrl: fileUrl)
                    
                    capturedImage = nil // Reset state
                })
            }
        }
        .sheet(isPresented: $showConfirmationSheet) {
            let sheetView = LaporGangguanConfirmationSheet(
                viewModel: viewModel,
                onSaveSuccess: {
                    showConfirmationSheet = false
                    // Tampilkan sheet sukses setelah jeda singkat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSuccessSheet = true
                    }
                }
            )
            
            // Terapkan modifier .presentationDetents secara kondisional
            if #available(iOS 16.4, *) {
                // Untuk iOS 16.4+, kita bisa menggunakan .height
                sheetView
                    .presentationDetents([.height(220)])
            } else if #available(iOS 16.0, *) {
                // Untuk iOS 16.0 - 16.3, .medium adalah fallback yang baik
                sheetView
                    .presentationDetents([.height(220)])
            } else {
                // Untuk iOS 15 dan di bawahnya, tampilkan sheet seperti biasa
                sheetView
            }
        }
        
        .sheet(isPresented: $showCancelConfirmationSheet) {
            let sheetView = LaporGangguanCancelSheet(
                viewModel: viewModel,
                onConfirmCancel: {
                    // Aksi ini akan dijalankan saat save berhasil
                    showCancelConfirmationSheet = true
                    dismiss()// Tutup sheet
                }
            )
            
            // Terapkan modifier .presentationDetents secara kondisional
            if #available(iOS 16.4, *) {
                // Untuk iOS 16.4+, kita bisa menggunakan .height
                sheetView
                    .presentationDetents([.height(220)])
            } else if #available(iOS 16.0, *) {
                // Untuk iOS 16.0 - 16.3, .medium adalah fallback yang baik
                sheetView
                    .presentationDetents([.height(220)])
            } else {
                // Untuk iOS 15 dan di bawahnya, tampilkan sheet seperti biasa
                sheetView
            }
        }
        .sheet(isPresented: $showSuccessSheet, onDismiss: {
            // Saat sheet sukses ditutup, tutup juga halaman ini
            dismiss()
        }) {
            LaporGangguanSuccessView()
        }
    }
    
    private func processImage(_ image: UIImage) -> UIImage? {
        // --- LANGKAH 1: UBAH UKURAN GAMBAR (RESIZE) ---
        let maxDimension: CGFloat = 1920.0 // Batas resolusi (misal: Full HD)
        var resizedImage = image

        // Hanya ubah ukuran jika gambar lebih besar dari batas
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let aspectRatio = image.size.width / image.size.height
            var newSize: CGSize
            
            if image.size.width > image.size.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
            
            // Buat gambar baru dengan ukuran yang lebih kecil
            let renderer = UIGraphicsImageRenderer(size: newSize)
            resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        
        // --- LANGKAH 2: TAMBAHKAN WATERMARK KE GAMBAR YANG SUDAH DIUBAH UKURANNYA ---
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss dd/MM/yyyy"
        let timestamp = dateFormatter.string(from: Date())
        let location = locationManager.locationString
        let watermarkText = "\(timestamp) - \(location)"
        
        // Sesuaikan ukuran font watermark dengan ukuran gambar yang baru
        let fontSize = resizedImage.size.width / 40
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8) // Sedikit transparan
        ]
        
        let renderer = UIGraphicsImageRenderer(size: resizedImage.size)
        let watermarkedImage = renderer.image { context in
            resizedImage.draw(at: .zero)
            
            // Posisi watermark di pojok kiri bawah
            let textRect = CGRect(x: 20, y: resizedImage.size.height - fontSize - 20, width: resizedImage.size.width - 40, height: fontSize + 10)
            (watermarkText as NSString).draw(in: textRect, withAttributes: textAttributes)
        }
        
        // --- LANGKAH 3: KOMPRES GAMBAR YANG SUDAH DI-WATERMARK ---
        // Gunakan kualitas kompresi yang wajar (misal: 0.7), tidak perlu loop.
        let compressionQuality: CGFloat = 0.3
        guard let finalData = watermarkedImage.jpegData(compressionQuality: compressionQuality) else { return nil }
        
        print("Ukuran gambar akhir: \(Double(finalData.count) / 1_000_000.0) MB")
        
        return UIImage(data: finalData)
    }

}


// MARK: - 4. Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            Text(value)
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
        }
    }
}

struct EditableInfoRow: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            TextField("", text: $text, prompt: Text("Masukan " + label).foregroundColor(.gray))
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
                .padding(10)
                .background(Color(hex: "#F9FAFB"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
        }
    }
}

struct PickerRowDynamic: View {
    let label: String
    @Binding var selection: CategorySelection?
    let options: [CategorySelection]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            if isLoading {
                ProgressView()
            } else {
                Menu {
                    ForEach(options) { option in
                        Button(option.name) {
                            self.selection = option
                        }
                    }
                } label: {
                    HStack {
                        Text(selection?.name ?? "Pilih Kategori")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color(hex: "#1F1F1F"))
                    .padding(10)
                    .background(Color(hex: "#F9FAFB"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
    }
}

struct PickerRowDirectory: View {
    let label: String
    let selection: DirectorySelection? // Hanya untuk menampilkan nama
    let isLoading: Bool
    @Binding var isPresented: Bool // Binding untuk menampilkan sheet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            Button(action: {
                if !isLoading {
                    self.isPresented = true
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                        Spacer()
                    } else {
                        Text(selection?.prettyName ?? "Pilih Direktori")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "magnifyingglass") // Ikon pencarian
                            .foregroundColor(.secondary)
                    }
                }
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#F9FAFB"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
            }
            .disabled(isLoading)
        }
    }
}

struct PickerRowPIC: View {
    let label: String
    @Binding var selection: PICSelection?
    let options: [PICSelection]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            if isLoading {
                ProgressView()
            } else {
                Menu {
                    ForEach(options) { option in
                        Button(option.userName) {
                            self.selection = option
                        }
                    }
                } label: {
                    HStack {
                        Text(selection?.userName ?? "Pilih PIC")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .font(.custom("Inter18pt-Regular", size: 14))
                    .foregroundColor(Color(hex: "#1F1F1F"))
                    .padding(10)
                    .background(Color(hex: "#F9FAFB"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
    }
}

struct NoteEditor: View {
    let label: String
    @Binding var text: String
    
    init(label: String, text: Binding<String>) {
        self.label = label
        self._text = text
        // Baris ini menghapus warna latar belakang default dari semua TextEditor di aplikasi.
        UITextView.appearance().backgroundColor = .clear
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            TextField("", text: $text, prompt: Text("Masukan " + label).foregroundColor(.gray))
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
                .padding(10)
                .background(Color(hex: "#F9FAFB"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
        }
    }
}

struct ImageUploadSection: View {
    @Binding var images: [UploadedImageItem]
    @Binding var showCamera: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Upload Gambar")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            // Daftar gambar yang sudah di-upload
            ForEach(images) { item in
                UploadedPhotoRow(item: item) {
                    // Aksi hapus
                    withAnimation {
                        images.removeAll { $0.id == item.id }
                    }
                }
            }
            
            // [DISEDERHANAKAN] Tombol statis, belum berfungsi
            Button(action: {
                // TODO: Tambahkan aksi untuk membuka view kamera kustom Anda nanti
                print("Tombol Buka Kamera ditekan")
                // Contoh menambahkan item dummy untuk tes UI
                withAnimation {
//                    images.append(UploadedImageItem(fileName: "capture_\(images.count + 1).jpg"))
                    showCamera = true
                }
            }) {
                Text("Buka Kamera")
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color(hex: BaseEnv.baseColor))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

struct UploadedPhotoRow: View {
    let item: UploadedImageItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "camera.fill")
                .foregroundColor(Color(hex: "#1F1F1F"))
            Text(item.fileName)
                .font(.custom("Inter18pt-Medium", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
                .lineLimit(1)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .foregroundColor(Color(hex: "#1F1F1F"))
            }
        }
        .padding(10)
        .background(Color(hex: "#F9FAFB"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // [PERBAIKAN] Hanya ambil gambar asli, proses dipindahkan ke SwiftUI
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct LaporGangguanConfirmationSheet: View {
    @ObservedObject var viewModel: LaporGangguanResultViewModel
    @Environment(\.dismiss) var dismiss
    
    // Callback untuk memberitahu parent view bahwa save berhasil
    var onSaveSuccess: () -> Void
    
    // State untuk alert hasil
    @State private var showResultAlert = false
    @State private var resultAlertTitle = ""
    @State private var resultAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 20)
        {
            Text("Konfirmasi Lapor Gangguan")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            Text("Apakah Anda yakin ingin melanjutkan?")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)

            HStack(spacing: 10){
                Button(action: {
                    dismiss()
                }) {
                    Text("Batalkan")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.black)
                        .background(Color(.white))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    Task {
                        do {
                            try await viewModel.submitLaporan()
                            // Panggil callback onSaveSuccess
                            onSaveSuccess()
                        } catch {
                            // Jika gagal, tampilkan alert di dalam sheet ini
                            resultAlertTitle = "Gagal"
                            resultAlertMessage = "Tidak dapat mengirim laporan: \(error.localizedDescription)"
                            showResultAlert = true
                        }
                    }
                }) {
                    Text("Konfirmasi")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(hex: BaseEnv.baseColor))
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.white)
        .alert(resultAlertTitle, isPresented: $showResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultAlertMessage)
        }
    }
}

struct LaporGangguanCancelSheet: View {
    @ObservedObject var viewModel: LaporGangguanResultViewModel
    @Environment(\.dismiss) var dismiss
    var onConfirmCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Batalkan Laporan")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            Text("Apakah Anda yakin untuk meninggalkan halaman laporan?")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)

            HStack(spacing: 10){
                Button(action: {
                    dismiss()
                    
                }) {
                    Text("Tidak")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.black)
                        .background(Color(.white))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Panggil callback untuk menutup halaman utama
                    Task {
                        await viewModel.deleteUploadedTempFiles()
                        // Panggil callback setelah selesai
                        onConfirmCancel()
                    }
                }) {
                    Text("Ya")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(hex: BaseEnv.baseColor))
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.white)
    }
}


@MainActor
class DirectorySearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var filteredDirectories: [DirectorySelection] = []
    
    private var allDirectories: [DirectorySelection]
    private var cancellables = Set<AnyCancellable>()
    
    init(allDirectories: [DirectorySelection]) {
        self.allDirectories = allDirectories
        self.filteredDirectories = allDirectories
        
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.filterDirectories(query: query)
            }
            .store(in: &cancellables)
    }
    
    private func filterDirectories(query: String) {
        if query.isEmpty {
            filteredDirectories = allDirectories
        } else {
            filteredDirectories = allDirectories.filter {
                $0.prettyName.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

// MARK: - [PERUBAHAN 2] View baru untuk sheet pencarian direktori
struct DirectorySearchView: View {
    @StateObject private var viewModel: DirectorySearchViewModel
    @Environment(\.dismiss) var dismiss
    
    var onSelection: (DirectorySelection) -> Void
        
    init(allDirectories: [DirectorySelection], onSelection: @escaping (DirectorySelection) -> Void) {
        _viewModel = StateObject(wrappedValue: DirectorySearchViewModel(allDirectories: allDirectories))
        self.onSelection = onSelection
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0){
                CustomSearchBar(searchText: $viewModel.searchText)
                                    .padding()
                List(viewModel.filteredDirectories) { directory in
                    Button(action: {
                        onSelection(directory) // Kembalikan pilihan
                        dismiss()// Tutup sheet
                    }) {
                        Text(directory.prettyName)
                            .foregroundColor(.black)
                    }
                    .listRowBackground(Color.white)
                }
                .listStyle(.plain)
            }
            
            .background(Color.white) // Latar belakang utama list
            .navigationTitle("Pilih Direktori")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(CustomToolbarBackgroundModifier())
            
        }
        .accentColor(Color(BaseEnv.baseColor))
    }
}

struct CustomSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Cari direktori...", text: $searchText)
                .foregroundColor(.black)
        }
        .padding(10)
        .background(Color(UIColor.white))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
    }
}

fileprivate struct CustomToolbarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbarBackground(Color.white, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            // Fallback untuk iOS 15. Tampilan default biasanya sudah cukup untuk sheet.
            content
        }
    }
}


// MARK: - Preview
#Preview {
    NavigationView {
        LaporGangguanResultView()
    }
}
