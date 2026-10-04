//
//  LoginView.swift
//  Assets Management
//
//  Created by Dony on 01/07/25.
//

import SwiftUI

struct LoginRequest: Encodable {
    let identifier: String
    let password: String
}

// Struct untuk menangkap response dari server, disesuaikan dengan response JWT.
// Harus conform ke 'Decodable' agar bisa dibuat dari JSON.
struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    // Gunakan CodingKeys untuk memetakan snake_case dari JSON ke camelCase di Swift.
    // Ini adalah praktik standar dan sangat direkomendasikan.
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct CaptchaChallenge: Identifiable {
    let id = UUID()
    let num1: Int
    let num2: Int
    let isAddition: Bool
}

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    // @State digunakan untuk menyimpan input dari pengguna.
    // Perubahan pada variabel ini akan otomatis diperbarui di UI.
    @State private var emailOrNIP = ""
    @State private var password = ""
    
    // State untuk mengelola UI selama proses network call
    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    // State untuk CAPTCHA
    @State private var showCaptchaSheet = false
    @State private var captchaNum1 = 0
    @State private var captchaNum2 = 0
    @State private var captchaOperationIsAddition = true
    @State private var captchaChallenge: CaptchaChallenge?

    //MAX LOGIN
    private let maxLoginAttempts = 3
    
    var body: some View {
        // VStack utama untuk mengatur semua elemen secara vertikal.
        ZStack{
            VStack(spacing: 0) {
                
                Spacer()
                
                // 1. Logo Aplikasi
                Image("ic_logo_login") // Ganti "ic_logo" dengan nama aset gambar Anda
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .padding(.bottom, 20)
                
                // 3. Form Input
                VStack(alignment: .leading, spacing: 20) {
                    // Input untuk NIP atau Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NIP atau Email")
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color(.black))
                        
                        TextField("", text: $emailOrNIP, prompt: Text("Masukan NIP atau Email").foregroundColor(.gray))
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(.black) // Mengatur warna teks yang diketik menjadi hitam
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Input untuk Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(Color(.black))
                        
                        SecureField("", text: $password, prompt: Text("Masukan Password").foregroundColor(.gray))
                            .font(.custom("Inter18pt-Regular", size: 14))
                            .foregroundColor(.black)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                
                Spacer()
                
                // 4. Tombol Login
                Button(action: {
                    // Validasi input sebelum menampilkan captcha
                    guard !emailOrNIP.isEmpty, !password.isEmpty else {
                        self.alertMessage = "NIP/Email dan Password tidak boleh kosong."
                        self.showAlert = true
                        return
                    }
                    // [PERBAIKAN] Buat soal CAPTCHA dan picu sheet dengan mengisinya
                    self.captchaChallenge = generateCaptcha()
                }) {
                    Text("Log In")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(hex: BaseEnv.baseColor))
                        .cornerRadius(10)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24) // Memberi jarak dari tepi kiri dan kanan
            .padding(.bottom)
            .background(Color.white.ignoresSafeArea()) // Latar belakang putih untuk seluruh halaman
            if isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("Logging in...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Info"), message: Text(alertMessage ?? "Terjadi kesalahan"), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $captchaChallenge) { challenge in
            if #available(iOS 16.0, *) {
                CaptchaSheetView(
                    num1: challenge.num1,
                    num2: challenge.num2,
                    isAddition: challenge.isAddition,
                    onSuccess: {
                        // Aksi ini dijalankan jika CAPTCHA benar
                        captchaChallenge = nil // Tutup sheet
                        Task {
                            await loginUser()
                        }
                    }
                )
                .presentationDetents([.height(250)])
            } else {
                CaptchaSheetView(
                    num1: challenge.num1,
                    num2: challenge.num2,
                    isAddition: challenge.isAddition,
                    onSuccess: {
                        // Aksi ini dijalankan jika CAPTCHA benar
                        captchaChallenge = nil // Tutup sheet
                        Task {
                            await loginUser()
                        }
                    }
                )
            }
        }
    }
    
    private func generateCaptcha() -> CaptchaChallenge {
        let isAddition = Bool.random()
        var num1: Int
        var num2: Int
        
        if isAddition {
            num1 = Int.random(in: 1...10)
            num2 = Int.random(in: 1...10)
        } else {
            num1 = Int.random(in: 2...10)
            num2 = Int.random(in: 1..<num1)
        }
        
        return CaptchaChallenge(num1: num1, num2: num2, isAddition: isAddition)
    }
    
    // MARK: - 2. Fungsi API Call
    func loginUser() async {
        // Validasi input tidak boleh kosong
        guard !emailOrNIP.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.alertMessage = "NIP atau Email tidak boleh kosong."
            self.showAlert = true
            return
        }
        
        // Cek apakah akun sedang terkunci
        if isAccountLocked(for: emailOrNIP) {
            self.alertMessage = "Anda telah gagal login sebanyak 3 kali. Akun terkunci selama 1 jam."
            self.showAlert = true
            return
        }
        
        isLoading = true
        
        guard let url = URL(string: "\(BaseEnv.baseURL)/auth_api/login") else {
            print("Error: URL tidak valid."); isLoading = false; return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("insomnia/10.0.0", forHTTPHeaderField: "User-Agent")
        
        let requestBody = LoginRequest(identifier: emailOrNIP, password: password)
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            print("Error: Gagal melakukan encoding JSON: \(error)"); isLoading = false; return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                handleLoginFailure(message: "Respons server tidak valid.")
                return
            }
            
            // Jika login GAGAL (misal: 401 Unauthorized)
            if httpResponse.statusCode != 200 {
                incrementFailureCount(for: emailOrNIP)
                let attempts = getFailureCount(for: emailOrNIP)
                if attempts >= maxLoginAttempts {
                    lockAccount(for: emailOrNIP)
                    handleLoginFailure(message: "Anda telah gagal login sebanyak 3 kali. Akun terkunci selama 1 jam.")
                } else {
                    handleLoginFailure(message: "Login gagal. Sisa percobaan: \(maxLoginAttempts - attempts).")
                }
                return
            }
            
            // Jika login SUKSES
            let decodedResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            resetFailureCount(for: emailOrNIP)

            // Panggil TokenService untuk menyimpan token
            TokenService.shared.saveTokens(
                accessToken: decodedResponse.accessToken,
                refreshToken: decodedResponse.refreshToken
            )

            // Contoh cara mendekode dan menggunakan data dari token
            authService.login()
            
        } catch {
            handleLoginFailure(message: "Terjadi kesalahan: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func handleLoginFailure(message: String) {
        self.alertMessage = message
        self.showAlert = true
        self.isLoading = false
    }
    
    // MARK: - 3. Login Attempt Management
    
    private func getFailureCount(for identifier: String) -> Int {
        return UserDefaults.standard.integer(forKey: "loginAttempts_\(identifier)")
    }
    
    private func incrementFailureCount(for identifier: String) {
        let currentCount = getFailureCount(for: identifier)
        UserDefaults.standard.set(currentCount + 1, forKey: "loginAttempts_\(identifier)")
    }
    
    private func resetFailureCount(for identifier: String) {
        UserDefaults.standard.removeObject(forKey: "loginAttempts_\(identifier)")
        UserDefaults.standard.removeObject(forKey: "lockoutEndDate_\(identifier)")
    }
    
    private func lockAccount(for identifier: String) {
        let lockoutEndDate = Date().addingTimeInterval(3600) // 1 jam dari sekarang
        UserDefaults.standard.set(lockoutEndDate, forKey: "lockoutEndDate_\(identifier)")
    }
    
    private func isAccountLocked(for identifier: String) -> Bool {
        guard let lockoutEndDate = UserDefaults.standard.object(forKey: "lockoutEndDate_\(identifier)") as? Date else {
            return false // Tidak ada tanggal kunci, berarti tidak terkunci
        }
        // Akun terkunci jika tanggal sekarang masih sebelum tanggal akhir kunci
        return Date() < lockoutEndDate
    }
}

struct CaptchaSheetView: View {
    let num1: Int
    let num2: Int
    let isAddition: Bool
    var onSuccess: () -> Void
    
    @State private var userAnswer: String = ""
    @State private var showError = false
    @Environment(\.dismiss) var dismiss
    
    private var correctAnswer: Int {
        isAddition ? num1 + num2 : num1 - num2
    }
    
    private var question: String {
        "Berapa hasil dari \(num1) \(isAddition ? "+" : "-") \(num2)?"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Verifikasi")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            Text(question)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black) 
            
            TextField("Jawaban", text: $userAnswer)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    // Efek goyang jika jawaban salah
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(showError ? Color.red : Color.gray.opacity(0.4), lineWidth: 2)
                            .offset(x: showError ? -5 : 0)
                            .animation(.interpolatingSpring(stiffness: 300, damping: 10).repeatCount(3, autoreverses: true), value: showError)
                    }
                )

            Button("Verifikasi") {
                if Int(userAnswer) == correctAnswer {
                    onSuccess()
                } else {
                    userAnswer = ""
                    withAnimation {
                        showError = true
                    }
                    // Reset state error setelah animasi selesai
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showError = false
                    }
                }
            }
            .font(.custom("Inter18pt-SemiBold", size: 14))
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(Color(hex: "#205781"))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.white)
    }
}

// Preview Provider untuk menampilkan di Xcode Canvas
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
