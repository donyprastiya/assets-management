import SwiftUI

@MainActor
class DatabaseAsetResultViewModel: ObservableObject {
    
    // Sekarang menyimpan satu objek AssetDetailResponse, bukan array
    @Published var assetDetail: AssetDetailResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchData(type: String, value: String) async {
        isLoading = true
        errorMessage = nil
        
        guard var urlComponents = URLComponents(string: "\(BaseEnv.baseURL)/asset") else {
            errorMessage = "URL tidak valid."; isLoading = false; return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "value", value: value)
        ]
        
        guard let url = urlComponents.url else {
            errorMessage = "URL tidak dapat dibuat."; isLoading = false; return
        }
        
        guard let token = await AuthenticationService.shared.getValidAccessToken() else {
            errorMessage = "Sesi tidak valid."; isLoading = false; return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("--- RAW JSON RESPONSE ---\n\(jsonString)\n-------------------------")
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.errorMessage = "Data tidak ditemukan atau terjadi kesalahan server."
                self.isLoading = false
                return
            }
            
            // Decode langsung ke AssetDetailResponse
            let decodedResponse = try JSONDecoder().decode(AssetDetailResponse.self, from: data)
            self.assetDetail = decodedResponse
            Storage.saveData(data: decodedResponse, forKey: "currentAssetDetail")
            print("Data aset berhasil disimpan ke storage.")
            
        } catch {
            self.errorMessage = "Data tidak ditemukan"
            print("Decoding Error: \(error)")
        }
        
        isLoading = false
    }
}


// MARK: - 3. Main View
struct DatabaseAsetResultView: View {
    
    @StateObject private var viewModel = DatabaseAsetResultViewModel()
    
    @Environment(\.dismiss) var dismiss
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            Color(.white).ignoresSafeArea()
            VStack {
                HStack {
                    // Tombol untuk menutup bottom sheet
                    Button(action: {
                        dismiss()
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
                

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let asset = viewModel.assetDetail {
                            // Tampilkan data utama
                            TextPropertyRow(label: "Asset Name", value: asset.name)
                            TextPropertyRow(label: "Serial Number", value: asset.serialNumber)
                            TextPropertyRow(label: "Category", value: asset.categoryName)
                            TextPropertyRow(label: "Direktori", value: asset.directoryFullName)
                            TextPropertyRow(label: "Last Update", value: asset.lastUpdate)
                            
                            // Loop melalui properti dinamis
                            
                            if showDetails {
                                ForEach(asset.properties) { property in
                                    if property.columnType == "file" {
                                        FilePropertyRow(property: property)
                                    } else {
                                        let valueString = property.values.map { $0.propertyValues }.joined(separator: ", ")
                                        TextPropertyRow(label: property.name, value: valueString)
                                    }
                                }
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
                    )
                    
                    if !showDetails{
                        Button(action: {
                            withAnimation {
                                showDetails = true
                            }
                        }) {
                            Text("Detail")
                                .font(.custom("Inter18pt-SemiBold", size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: BaseEnv.baseColor))
                                .cornerRadius(10)
                        }
                    }
                }
                
                
                if viewModel.assetDetail != nil && !viewModel.isLoading{
                    NavigationLink(destination: DatabaseAsetEditView()) {
                        Text("Edit")
                            .font(.custom("Inter18pt-SemiBold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: BaseEnv.baseColor))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        
        .navigationBarBackButtonHidden(true)
        .onAppear {
            Task {
                await getDataScan()
            }
        }
    }
    
    func getDataScan() async {
        // Reset state untuk memberikan kesan "memulai dari awal"
        viewModel.assetDetail = nil
        viewModel.errorMessage = nil
        viewModel.isLoading = true
        
        guard let assetValue = Storage.getString(forKey: "lastScannedValue") else {
            viewModel.errorMessage = "Tidak ada data pindaian yang ditemukan."
            viewModel.isLoading = false // Matikan loading jika gagal di awal
            return
        }
        
        let assetType = Storage.getString(forKey: "lastScannedType") ?? "serial_number"
        
        // Panggil fetchData yang sekarang lebih fokus pada network call
        await viewModel.fetchData(type: assetType, value: assetValue)
    }
}

// MARK: - Helper Views for Rows

struct TextPropertyRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            Text(value ?? "-")
                .font(.custom("Inter18pt-SemiBold", size: 16))
                .foregroundColor(Color(hex: "#1F1F1F"))
        }
    }
}

struct FilePropertyRow: View {
    let property: AssetProperty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(property.name)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            
            ForEach(property.values) { value in
                // [PERUBAHAN] Ganti Button dengan NavigationLink
                
                // Tampilan link (label) tetap sama seperti sebelumnya
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(Color(hex: "#999999"))
                    
                    Text(URL(string: value.propertyValues)?.lastPathComponent ?? value.propertyValues)
                        .font(.custom("Inter18pt-Regular", size: 16))
                        .foregroundColor(Color(hex: "#1F1F1F"))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    NavigationLink(destination: DatabaseAsetPDFView(
//                        urlString: "value.propertyValues",
                        urlString: value.propertyValues,
                        title: URL(string: value.propertyValues)?.lastPathComponent ?? "File"
                    )) {
                        // "Label" dari NavigationLink adalah tampilan yang bisa diklik.
                        // Kita buat Text yang terlihat seperti tombol.
                        Text("Open")
                            .font(.custom("Inter18pt-SemiBold", size: 10))
                            .padding(.horizontal, 10) // Sedikit penyesuaian padding untuk Text
                            .padding(.vertical, 6)
                            .background(Color(hex: BaseEnv.baseColor))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#1F1F1F"))
                .padding(8)
                .background(Color(hex: "#F9FAFB"))
                .cornerRadius(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                
            }
        }
    }
}



// MARK: - Preview Provider
struct DatabaseAsetResultView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DatabaseAsetResultView()
        }
    }
}
