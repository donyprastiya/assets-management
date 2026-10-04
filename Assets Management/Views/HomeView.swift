import SwiftUI

enum ServiceDestination {
    case databaseAset
    case laporGangguan
    case listGangguan
    case kinerjaFasop
    case realtimeKesiapanFasop
    case monitoringFrekSistem
    case dataAset
    case lainnya
}

// MARK: - Main View with TabBar
struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    init() {
        // Membuat appearance baru untuk TabBar untuk mengubah warnanya.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        TabView {
            HomePageContentView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .accentColor(Color(hex: BaseEnv.baseColor))
    }
}


// MARK: - Home Page Content
struct HomePageContentView: View {
    @EnvironmentObject var viewRouter: ViewRouter
    var body: some View {
        ZStack {
            // Gambar ini menjadi latar belakang untuk bagian atas layar (header).
            Image("backgroud")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 0){
                HeaderView()
                    .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 24) {
                            Spacer()
                            Text("Daftar Layanan")
                                .font(.custom("Inter18pt-SemiBold", size: 14))
                                .foregroundColor(Color(.black))
                                .padding(.horizontal)
                            ServiceGridView()
                            Rectangle()
                                .fill(Color(hex: "#F2F4F7"))
                                .frame(height: 8)
                            InfoCardView(
                                title: "Pusat Informasi",
                                subtitle: "Biar makin kenal, yuk cek info berikut",
                                buttonText: "Lihat Selengkapnya",
                                gradientColors: [Color(hex: BaseEnv.baseColor), Color(hex: BaseEnv.baseColor)]
                            )
                            Rectangle()
                                .fill(Color(hex: "#F2F4F7"))
                                .frame(height: 8)
                            InfoCardView(
                                title: "Notifikasi",
                                subtitle: "Belum ada notifikasi",
                                buttonText: "Lihat Selengkapnya",
                                gradientColors: [Color(hex: BaseEnv.baseColor), Color(hex: BaseEnv.baseColor)]
                            )
                            Spacer().frame(height: 30)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white) // Latar belakang putih untuk area konten
                    }
                }
            }
            
            
            .ignoresSafeArea(edges: .top) // Agar ScrollView bisa naik sampai ke status bar
        }
    }
}

// MARK: - Reusable Components

struct HeaderView: View {
    var body: some View {
        ZStack {
            Color.clear
                .frame(height: 120)
                .ignoresSafeArea(edges: .top)
            
            HStack {
                Text(TokenService.shared.decode(jwtToken: TokenService.shared.getAccessToken() ?? "")?.data.name ?? "User")
                    .font(.custom("Inter18pt-SemiBold", size: 16))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 48)
        }
        .frame(height: 100)
    }
}

struct ServiceItem: Identifiable {
    let id = UUID()
    let imageName: String // Diubah dari iconName
    let title: String
    let destination: ServiceDestination
}

struct ServiceGridView: View {
    @EnvironmentObject var viewRouter: ViewRouter
    // Data untuk semua item layanan
    // Ganti nama string ini dengan nama aset gambar Anda yang sebenarnya.
    let serviceItems: [ServiceItem] = [
        ServiceItem(imageName: "ic_data", title: "Database Aset", destination: .databaseAset),
        ServiceItem(imageName: "ic_paper", title: "Lapor Gangguan", destination: .laporGangguan),
        ServiceItem(imageName: "ic_monitoring", title: "Maintenance Aset", destination: .listGangguan),
        ServiceItem(imageName: "ic_speed", title: "Kinerja Fasop", destination: .kinerjaFasop),
        ServiceItem(imageName: "ic_speed", title: "Realtime Kesiapan Fasop", destination: .realtimeKesiapanFasop),
        ServiceItem(imageName: "ic_monitoring", title: "Monitoring Frek Sistem", destination: .monitoringFrekSistem),
        ServiceItem(imageName: "ic_paper", title: "Data Aset", destination: .dataAset),
        ServiceItem(imageName: "ic_lainnya", title: "Lainnya", destination: .lainnya)
    ]
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(serviceItems) { item in
                    // 2. Gunakan Button, bukan NavigationLink
                    Button(action: {
                        // 3. Panggil fungsi show() dari viewRouter saat tombol ditekan
                        //    Kita hanya akan melakukannya untuk .databaseAset untuk saat ini.
                        if item.destination == .databaseAset {
                            viewRouter.show(.databaseAset)
                        } else if item.destination == .laporGangguan {
                            viewRouter.show(.laporGangguan)
                        } else if item.destination == .listGangguan {
                            viewRouter.show(.listGangguan)
                        } else if item.destination == .lainnya {
                            viewRouter.show(.lainnya)
                        }
                        else {
                            print("Navigasi untuk \(item.title) belum diimplementasikan sebagai full screen.")
                        }
                    }) {
                        // Tampilan tombolnya tetap sama
                        VStack(spacing: 8) {
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                            
                            Text(item.title)
                                .font(.custom("Inter18pt-Regular", size: 12))
                                .foregroundColor(Color(.black))
                                .multilineTextAlignment(.center)
                                .frame(height: 40)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
}

struct InfoCardView: View {
    let title: String
    let subtitle: String
    let buttonText: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Inter18pt-Bold", size: 16))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Button(action: { /* Aksi untuk tombol */ }) {
                HStack {
                    Text(buttonText)
                    Image(systemName: "arrow.right")
                }
                .font(.custom("Inter18pt-SemiBold", size: 14))
                .foregroundColor(Color(hex: BaseEnv.baseColor))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    
    // Properti untuk menampilkan data pengguna
    @Published var userName: String = ""
    @Published var userNIK: String = ""
    @Published var userEmail: String = ""
    @Published var userRole: String = ""
    
    // Properti untuk form ubah kata sandi
    @Published var oldPassword = ""
    @Published var newPassword = ""
    @Published var retypePassword = ""
    
    
    // State untuk UI
    @Published var isSubmittingPassword = false
    @Published var alertMessage: String?
    @Published var showAlert = false
    
    /// Memuat data pengguna dari token yang tersimpan.
    func loadUserData() {
        if let token = TokenService.shared.getAccessToken(),
           let decodedToken = TokenService.shared.decode(jwtToken: token) {
            
            self.userName = decodedToken.data.name
            self.userNIK = decodedToken.data.nip
            self.userEmail = decodedToken.data.email
            // Mengambil dan menampilkan role pertama dari daftar
            self.userRole = decodedToken.data.roles.first?.name.capitalized ?? "N/A"
        } else {
            // Fallback jika token tidak ada atau tidak valid
            self.userName = "Pengguna Tidak Ditemukan"
        }
    }
    
    private func validateNewPassword() -> String? {
        if newPassword.count < 8 {
            return "Password harus memiliki minimal 8 karakter."
        }
        if newPassword.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return "Password harus mengandung setidaknya satu huruf besar (A-Z)."
        }
        if newPassword.rangeOfCharacter(from: .lowercaseLetters) == nil {
            return "Password harus mengandung setidaknya satu huruf kecil (a-z)."
        }
        if newPassword.rangeOfCharacter(from: .decimalDigits) == nil {
            return "Password harus mengandung setidaknya satu angka (0-9)."
        }
        if newPassword != retypePassword {
            return "Kata sandi baru tidak cocok."
        }
        // Jika semua validasi lolos, kembalikan nil
        return nil
    }
    
    /// Mengirim perubahan kata sandi ke server.
    func submitNewPassword() async {
        guard !oldPassword.isEmpty, !newPassword.isEmpty, !retypePassword.isEmpty else {
            showAlert(message: "Semua field kata sandi harus diisi.")
            return
        }
        
        if let validationError = validateNewPassword() {
            showAlert(message: validationError)
            return
        }
        
        isSubmittingPassword = true
        
        do {
            // 1. Siapkan URL dan token
            let urlString = "\(BaseEnv.baseURL)/person/change_password"
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            guard let token = await AuthenticationService.shared.getValidAccessToken() else { throw URLError(.userAuthenticationRequired) }
            
            // 2. Buat request body dengan format x-www-form-urlencoded
            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "old_password", value: oldPassword),
                URLQueryItem(name: "new_password", value: newPassword),
                URLQueryItem(name: "repeat_password", value: retypePassword)
            ]
            let requestBody = components.query?.data(using: .utf8)
            
            // 3. Buat URLRequest
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = requestBody
            
            // 4. Lakukan API call
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            let decodedResponse = try JSONDecoder().decode(ChangePasswordResponse.self, from: data)
            
            // 5. Tampilkan hasil ke pengguna
            if decodedResponse.status {
                showAlert(message: decodedResponse.message)
                oldPassword = ""
                newPassword = ""
                retypePassword = ""
            } else {
                showAlert(message: decodedResponse.message)
            }
            
        } catch {
            showAlert(message: "Gagal mengubah kata sandi")
        }
        
        isSubmittingPassword = false
    }
    
    private func showAlert(message: String) {
        self.alertMessage = message
        self.showAlert = true
    }
}

struct ProfileView: View {
    @EnvironmentObject var viewRouter: ViewRouter
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authService: AuthenticationService
    @State private var isEditingPassword = false
    @State private var isShowingLogoutConfirmation = false
    
    var body: some View {
        ZStack {
            Image("backgroud")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 0){
                HeaderView()
                    .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            VStack(alignment: .leading, spacing: 20) {
                                Text(viewModel.userName)
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(.black)
                                
                                // Detail Aset (Read-only dan Picker)
                                ProfileInfoRow(label: "NIK", value: viewModel.userNIK)
                                ProfileInfoRow(label: "Nama", value: viewModel.userEmail)
                                ProfileInfoRow(label: "Role", value: viewModel.userRole)
                                
                                if isEditingPassword{
                                    EditablePasswordRow(label: "Old Password", text: $viewModel.oldPassword, isSecure: true)
                                    EditablePasswordRow(label: "New Password", text: $viewModel.newPassword, isSecure: true)
                                    EditablePasswordRow(label: "Retype Password", text: $viewModel.retypePassword, isSecure: true)
                                    
                                    Button(action: {
                                        Task {
                                            await viewModel.submitNewPassword()
                                            if !viewModel.showAlert {
                                                withAnimation { isEditingPassword = false }
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Text("Submit Password")
                                            Spacer()
                                            Image("ic_arrowblue")
                                        }
                                        .font(.custom("Inter18pt-SemiBold", size: 16))
                                        .foregroundColor(Color(hex: "#205781"))
                                    }
                                } else {
                                    Button(action: {
                                        Task {
                                            withAnimation { isEditingPassword = true }
                                        }
                                    }) {
                                        HStack {
                                            Text("Change Password")
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
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            )
                            Spacer().frame(height: 20)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                Button(action: {
                                    Task {
//                                        await authService.logout()
                                        isShowingLogoutConfirmation = true
                                    }
                                }) {
                                    HStack {
                                        Text("Logout")
                                        Spacer()
                                        Image("ic_arrowblue")
                                    }
                                    .font(.custom("Inter18pt-SemiBold", size: 16))
                                    .foregroundColor(Color(hex: "#205781"))
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            )
                            Spacer().frame(height: 300)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                    }
                    .padding(20)
                    .background(Color.white)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.loadUserData()
        }
        .alert("Info", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "Terjadi kesalahan.")
        }
        .sheet(isPresented: $isShowingLogoutConfirmation) {
            if #available(iOS 16.0, *) {
                LogoutConfirmationView()
                    .presentationDetents([.height(220)])
            } else {
                LogoutConfirmationView()
            } // Atur tinggi sheet agar tidak full screen
        }
    }
}

struct LogoutConfirmationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Konfirmasi Logout")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            Text("Apakah Anda yakin ingin keluar dari akun Anda?")
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)
            
            // Tombol Konfirmasi Logout
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
                    Task{
                            try await authService.logout()
                    }
                }) {
                    Text("Ya, Keluar")
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

struct ProfileInfoRow: View {
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

struct EditablePasswordRow: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(Color(hex: "#667085"))
            if isSecure {
                SecureField("", text: $text)
                    .modifier(ProfileTextFieldStyle())
            } else {
                TextField("", text: $text)
                    .modifier(ProfileTextFieldStyle())
            }
        }
    }
}

struct ProfileTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Inter18pt-Regular", size: 14))
            .padding(10)
            .foregroundColor(Color(hex: "#1F1F1F"))
            .background(Color(hex: "#F9FAFB"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
    }
}

// MARK: - View Extension for specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
