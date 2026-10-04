//
//  AuthenticationService.swift
//  Assets Management
//
//  Created by Dony on 01/07/25.
//

import SwiftUI

// MARK: - Codable Structs for Refresh API
struct RefreshTokenRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

// MARK: - Authentication Service
@MainActor
class AuthenticationService: ObservableObject {
    
    // [PERUBAHAN] Menjadikan service ini Singleton
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true

    // [PERUBAHAN] Init dibuat private agar hanya bisa ada satu instance
    init() {
        Task {
            await checkSessionValidity()
        }
    }
    
    /// Mengambil access token yang valid.
    /// Jika token saat ini sudah kedaluwarsa, fungsi ini akan otomatis mencoba me-refresh-nya.
    /// - Returns: Access token yang valid, atau nil jika sesi benar-benar berakhir.
    func getValidAccessToken() async -> String? {
        // 1. Cek dulu apakah token saat ini masih valid.
        if let accessToken = TokenService.shared.getAccessToken(),
           let decodedToken = TokenService.shared.decode(jwtToken: accessToken),
           decodedToken.exp > Date() {
            // Jika masih valid, langsung kembalikan.
            return accessToken
        }
        
        // 2. Jika tidak valid (atau tidak ada), coba refresh.
        let didRefreshSuccessfully = await refreshToken()
        
        // 3. Setelah refresh, ambil lagi token terbaru dari Keychain.
        return TokenService.shared.getAccessToken()
    }
    
    /// Memeriksa validitas sesi saat aplikasi dibuka.
    func checkSessionValidity() async {
        self.isLoading = true
        
        if await getValidAccessToken() != nil {
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
        
        self.isLoading = false
    }
    
    /// [REFACTOR] Fungsi refresh token sekarang mengembalikan Boolean (true jika sukses, false jika gagal).
    @discardableResult
    func refreshToken() async -> Bool {
        print("Access token kedaluwarsa, mencoba refresh...")
        
        guard let oldRefreshToken = TokenService.shared.getRefreshToken() else {
            await logout(); return false
        }
        
        if let decodedRefreshToken = TokenService.shared.decode(jwtToken: oldRefreshToken), decodedRefreshToken.exp <= Date() {
            await logout(); return false
        }
        
        guard let url = URL(string: "\(BaseEnv.baseURL)/auth_api/refresh") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = RefreshTokenRequest(refreshToken: oldRefreshToken)
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await logout(); return false
            }
            
            let newAccessTokenResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            
            TokenService.shared.saveTokens(
                accessToken: newAccessTokenResponse.accessToken,
                refreshToken: oldRefreshToken
            )
            
            self.isAuthenticated = true
            print("Refresh token berhasil. Sesi diperpanjang.")
            return true
            
        } catch {
            await logout(); return false
        }
    }
    
    func login() {
        self.isAuthenticated = true
    }
    
    func logout() async {
        TokenService.shared.deleteTokens()
        self.isAuthenticated = false
    }
}

struct ChangePasswordResponse: Decodable {
    let status: Bool
    let message: String
}
