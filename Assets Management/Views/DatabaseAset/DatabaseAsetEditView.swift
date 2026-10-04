//
//  DatabaseAsetEditView.swift
//  Assets Management
//
//  Created by Dony on 13/07/25.
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
class DatabaseAsetEditViewModel: ObservableObject {
    
    @Published var assetDetail: AssetDetailResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deletedFileIDs: [Int] = []
    @Published var tempFiles: [String] = []
    
    /// [PERBAIKAN] Fungsi ini sekarang async dan menggabungkan data kategori.
    func loadAssetForEditing() async {
        isLoading = true
        errorMessage = nil
        
        // 1. Ambil data aset yang tersimpan
        guard var savedAsset = Storage.getData(as: AssetDetailResponse.self, forKey: "currentAssetDetail") else {
            self.errorMessage = "Gagal memuat data aset dari storage."
            self.isLoading = false
            return
        }
        
        do {
            // 2. Ambil detail kategori berdasarkan categoryId
            guard let categoryId = savedAsset.categoryId else {
                // Jika tidak ada categoryId, tampilkan data apa adanya
                self.assetDetail = savedAsset
                self.isLoading = false
                return
            }
            let categoryDetail = try await getCategoryDetail(categoryId: categoryId)
            
            // 3. Bandingkan dan gabungkan properti
            let existingPropertyIDs = Set(savedAsset.properties.map { $0.id })
            
            for categoryProp in categoryDetail.properties {
                if !existingPropertyIDs.contains(categoryProp.id) {
                    let newEmptyProperty = AssetProperty(
                        id: categoryProp.id,
                        name: categoryProp.name,
                        columnType: categoryProp.columnType,
                        values: [] // Properti baru ditambahkan dengan nilai kosong
                    )
                    savedAsset.properties.append(newEmptyProperty)
                }
            }
            
            // 4. Update state dengan data yang sudah digabung
            self.assetDetail = savedAsset
            
            print("self.assetDetail")
            print(self.assetDetail as Any)
            
        } catch {
            self.errorMessage = "Gagal mengambil data kategori: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// [TAMBAHAN] Fungsi privat untuk mengambil detail kategori.
    private func getCategoryDetail(categoryId: String) async throws -> CategoryDetailResponse {
        let urlString = "\(BaseEnv.baseURL)/asset/get_category_by_id/\(categoryId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        guard let token = await AuthenticationService.shared.getValidAccessToken() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        print(response)
        
        return try JSONDecoder().decode(CategoryDetailResponse.self, from: data)
    }
    
    
    func addListDelete(fileId: String){
        if let intId = Int(fileId) {
            // Jika berhasil, tambahkan ke daftar ID yang akan dihapus.
            self.deletedFileIDs.append(intId)
            print(self.deletedFileIDs)
        }
    }
    
    func deleteTempFiles() async {
        // Hanya jalankan jika ada file di dalam tempFiles
        guard !tempFiles.isEmpty else {
            print("Tidak ada file sementara untuk dihapus.")
            return
        }
        
        print("Menghapus file sementara: \(tempFiles)")
        
        let urlString = "\(BaseEnv.baseURL)/asset/delete_temp_files"
        guard let url = URL(string: urlString) else { return }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeleteFilesRequest(files: self.tempFiles)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Berhasil menghapus file sementara dari server.")
            } else {
                print("Gagal menghapus file sementara dari server.")
            }
        } catch {
            print("Error saat menghapus file sementara: \(error)")
        }
    }
    
    /// Menyimpan semua perubahan ke server (simulasi).
    func saveChanges() async throws {
        @Environment(\.dismiss) var dismiss
        
        print("saveChanges1")
        print(self.assetDetail as Any)
        guard let currentAsset = self.assetDetail,
              let assetId = Int(currentAsset.id ?? ""),
              let categoryId = Int(currentAsset.categoryId ?? ""),
              let directoryId = Int(currentAsset.directoryId ?? "1") // Fallback ke 1 jika tidak ada
        else {
            throw URLError(.badURL) // Atau error kustom yang lebih sesuai
        }
        print(currentAsset)
        // 1. Siapkan 'properties' untuk request body
        print("saveChanges2")
        var editedProperties: [PropertyEditItem] = []
        for property in currentAsset.properties {
            // Lakukan perulangan untuk SETIAP nilai di dalam properti
            for valueItem in property.values {
                if let propertyId = Int(property.id), !valueItem.propertyValues.isEmpty {
                    let editItem = PropertyEditItem(id: propertyId, value: valueItem.propertyValues)
                    editedProperties.append(editItem)
                }
            }
        }
        print("saveChanges3")
        // 2. Buat request body
        let requestBody = EditAssetRequest(
            id: assetId,
            name: currentAsset.name ?? "",
            serialNumber: currentAsset.serialNumber ?? "",
            techidentno: currentAsset.serialNumber ?? "",
            categoryId: categoryId,
            directoryId: directoryId,
            properties: editedProperties,
            filesToDelete: deletedFileIDs
        )
        
        // 3. Siapkan URL dan request
        let urlString = "\(BaseEnv.baseURL)/asset/edit"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        guard let token = await AuthenticationService.shared.getValidAccessToken() else { throw URLError(.userAuthenticationRequired) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 4. Encode body dan lakukan API call
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // Untuk debugging
        request.httpBody = try encoder.encode(requestBody)
        
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("--- REQUEST BODY ---\n\(jsonString)\n--------------------")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let jsonString = String(data: data, encoding: .utf8) {
            print("--- RAW JSON RESPONSE ---\n\(jsonString)\n-------------------------")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // TODO: Decode respons sukses jika diperlukan
        print("Perubahan berhasil disimpan!")
    }
}

struct DatabaseAsetEditView: View {
    
    @StateObject var viewModel = DatabaseAsetEditViewModel()
    @Environment(\.dismiss) var dismiss
    
    
    @State private var isShowingConfirmationSheet = false
    @State private var isShowingCancelSheet = false
    
    var body: some View {
        ZStack {
            Color(.white).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Kustom
                HStack {
                    // Tombol untuk menutup bottom sheet
                    Button(action: {
                        isShowingCancelSheet = true
//                        dismiss()
                        // Aksi untuk menutup, misalnya: dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    
                    Spacer() // Mendorong judul ke tengah
                    
                    Text("Data Asset")
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
                Spacer()
                // Konten yang bisa di-scroll
                if viewModel.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundColor(.red).padding()
                } else if let $assetDetail = Binding($viewModel.assetDetail) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // [PERBAIKAN] Menampilkan field utama sebagai TextField yang bisa diedit
                            ReadOnlyPropertyRow(label: "Asset Name", value: $assetDetail.name.wrappedValue)
                            ReadOnlyPropertyRow(label: "Serial Number", value: $assetDetail.serialNumber.wrappedValue)
                            // Kategori dan Last Update biasanya tidak bisa diedit
                            ReadOnlyPropertyRow(label: "Category", value: $assetDetail.categoryName.wrappedValue)
                            ReadOnlyPropertyRow(label: "Directory", value: $assetDetail.directoryFullName.wrappedValue)
                            ReadOnlyPropertyRow(label: "Last Update", value: $assetDetail.lastUpdate.wrappedValue)
                            
                            // [PERBAIKAN] Menggunakan .indices untuk iterasi yang aman pada binding.
                            ForEach($assetDetail.properties.indices, id: \.self) { index in
                                let propertyBinding = $assetDetail.properties[index]
                                if propertyBinding.wrappedValue.columnType == "file" {
                                    EditableFileRow(property: propertyBinding)
                                } else {
                                    EditableTextRow(property: propertyBinding)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )                    }
                }
                Spacer()
                // Tombol Simpan
                Button(action: {
                    isShowingConfirmationSheet = true
                }) {
                    Text("Simpan Perubahan")
                        .font(.custom("Inter18pt-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: BaseEnv.baseColor))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $isShowingCancelSheet) {
            // [PERBAIKAN] Teruskan ViewModel DAN sebuah callback 'onSaveSuccess'
            let sheetView = ManualInputSheetCancelEdit(
                    viewModel: viewModel,
                    onSaveSuccess: {
                        // Aksi ini akan dijalankan saat save berhasil
                        isShowingCancelSheet = true // Tutup sheet
                        dismiss() // Tutup halaman Edit untuk kembali ke Result
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
        .sheet(isPresented: $isShowingConfirmationSheet) {
            // [PERBAIKAN] Teruskan ViewModel DAN sebuah callback 'onSaveSuccess'
            let sheetView = ManualInputSheetSave(
                    viewModel: viewModel,
                    onSaveSuccess: {
                        // Aksi ini akan dijalankan saat save berhasil
                        isShowingConfirmationSheet = true // Tutup sheet
                        dismiss() // Tutup halaman Edit untuk kembali ke Result
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
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await viewModel.loadAssetForEditing()
            }
        }
    }
}

struct ManualInputSheetSave: View {
    @ObservedObject var viewModel: DatabaseAsetEditViewModel
    @Environment(\.dismiss) var dismiss
    
    var onSaveSuccess: () -> Void
        
        // State untuk alert hasil
    @State private var showResultAlert = false
    @State private var resultAlertTitle = ""
    @State private var resultAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 20)
        {
            Text("Konfirmasi Edit Data Asset")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            Text("Apakah Anda yakin ingin melanjutkan?")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)

            HStack(spacing: 10){
                Button(action: {
                    print("Batalkan")
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
                    print("Yes")
                    Task{
                        do{
                            try await viewModel.saveChanges()
                            onSaveSuccess()
                        }catch {
                            print("Gagal menyimpan perubahan: \(error.localizedDescription)")
                            resultAlertTitle = "Gagal"
                            resultAlertMessage = "Tidak dapat menyimpan perubahan: \(error.localizedDescription)"
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

struct ManualInputSheetCancelEdit: View {
    @ObservedObject var viewModel: DatabaseAsetEditViewModel
    @Environment(\.dismiss) var dismiss
    
    var onSaveSuccess: () -> Void
        
        // State untuk alert hasil
    @State private var showResultAlert = false
    @State private var resultAlertTitle = ""
    @State private var resultAlertMessage = ""
    
    var body: some View {
        VStack(spacing: 20)
        {
            Text("Batalkan Edit Data Asset")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            Text("Apakah Anda yakin untuk meninggalkan halaman edit?")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)

            HStack(spacing: 10){
                Button(action: {
                    print("Batalkan")
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
                    print("Yes")
                    Task{
                        do{
                            try await viewModel.deleteTempFiles()
                            onSaveSuccess()
                        }catch {
                            onSaveSuccess()
                        }
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
        .alert(resultAlertTitle, isPresented: $showResultAlert) {
            Button("OK", role: .cancel) {}
            } message: {
            Text(resultAlertMessage)
        }
    }
}



struct ReadOnlyPropertyRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            Text(value ?? "-")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#F9FAFB"))
                .cornerRadius(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
}

struct EditableMainPropertyRow: View {
    let label: String
    @Binding var value: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            TextField(label, text: Binding(
                get: { value ?? "" },
                set: { value = $0 }
            ))
            .font(.custom("Inter18pt-Regular", size: 14))
            .foregroundColor(Color(hex: "#1F1F1F"))
            .padding(10)
            .background(Color(hex: "#F9FAFB"))
            .cornerRadius(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
        }
    }
}


struct TextPropertyEditRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            Text(value ?? "-")
                .font(.custom("Inter18pt-SemiBold", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
            
        }
    }
}

struct EditableTextRow: View {
    @Binding var property: AssetProperty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            TextField("Value", text: Binding(
                get: { property.values.first?.propertyValues ?? "" },
                set: { newValue in
                    if property.values.indices.contains(0) {
                        property.values[0].propertyValues = newValue
                    } else {
                        property.values.append(PropertyValue(id: UUID().uuidString, propertyValues: newValue))
                    }
                }
            ))
            .font(.custom("Inter18pt-Regular", size: 14))
            .foregroundColor(Color(hex: "#1F1F1F"))
            .padding(10)
            .background(Color(hex: "#F9FAFB"))
            .cornerRadius(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
        }
    }
}

struct EditableFileRow: View {
    @Binding var property: AssetProperty
    @State private var showFileImporter = false
    @State private var isUploading = false
    @StateObject var viewModel = DatabaseAsetEditViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(property.name)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
        
            ForEach(property.values) { value in
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text(URL(string: value.propertyValues)?.lastPathComponent ?? value.propertyValues)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        removeFile(withId: value.id)
                    }) {
                        HStack {
                            if isUploading {
                                ProgressView()
                            } else {
                                Text("Hapus")
                                    .font(.custom("Inter18pt-SemiBold", size: 10))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: BaseEnv.baseColor))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        
                    }
                }
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
                .padding(10)
                .background(Color(hex: "#F9FAFB"))
                .cornerRadius(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            
            Button(action: { showFileImporter = true }) {
                HStack {
                    Text("+ Tambah File")
                }
            }
            .frame(maxWidth: .infinity)
            .font(.custom("Inter18pt-SemiBold", size: 14))
            .foregroundColor(.white)
            .padding(10)
            .background(Color(hex: BaseEnv.baseColor))
            .cornerRadius(8)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.item],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }
                
                // Panggil fungsi upload di dalam Task
                Task {
                    isUploading = true
                    do {
                        // Dapatkan akses ke file
                        let isAccessing = selectedFile.startAccessingSecurityScopedResource()
                        defer {
                            if isAccessing { selectedFile.stopAccessingSecurityScopedResource() }
                        }
                        
                        // Panggil service untuk upload
                        let fileUrlFromServer = try await UploadService.uploadFile(
                            fileURL: selectedFile,
                            propertyId: property.id
                        )
                        
                        // Jika berhasil, tambahkan URL baru ke daftar
                        let newFileValue = PropertyValue(id: UUID().uuidString, propertyValues: fileUrlFromServer)
                        property.values.append(newFileValue)
                        
                        if let fileName = URL(string: fileUrlFromServer)?.lastPathComponent {
                            viewModel.tempFiles.append(fileName)
                            print("Daftar file sementara: \(viewModel.tempFiles)")
                        }
                        
                        
                        print("Berhasil Menambah file: \(newFileValue)")
                        
                    } catch {
                        // TODO: Tampilkan alert jika upload gagal
                        print("Gagal upload file: \(error.localizedDescription)")
                    }
                    isUploading = false
                }
            } catch {
                print("Gagal memilih file: \(error.localizedDescription)")
            }
        }
    }
    
    private func removeFile(withId fileId: String) {
        property.values.removeAll { $0.id == fileId }
        viewModel.addListDelete(fileId: fileId)
    }
}



#Preview {
    DatabaseAsetEditView()
}
