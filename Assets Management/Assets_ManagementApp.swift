//
//  Assets_ManagementApp.swift
//  Assets Management
//
//  Created by Dony on 01/07/25.
//

import SwiftUI

@main
struct Assets_ManagementApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var viewRouter = ViewRouter()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                CheckView()
                    .environmentObject(authService)
                    .environmentObject(viewRouter)
            }
            .fullScreenCover(item: $viewRouter.currentFullScreenDestination) { destination in
                switch destination {
                case .databaseAset:
                    NavigationView {
                        DatabaseAsetView()
                            .environmentObject(viewRouter) // Sediakan router ke view ini juga
                    }
                case .laporGangguan:
                    NavigationView {
                        LaporGangguanView()
                            .environmentObject(viewRouter) // Sediakan router ke view ini juga
                    }
                case .homeAset:
                    NavigationView {
                        HomeView()
                            .environmentObject(viewRouter) // Sediakan router ke view ini juga
                    }
                case .listGangguan:
                    NavigationView {
                        ListGangguanView()
                            .environmentObject(viewRouter) // Sediakan router ke view ini juga
                    }
                case .lainnya:
                    NavigationView {
                        ListServiceView()
                            .environmentObject(viewRouter) // Sediakan router ke view ini juga
                    }
                }
            }
        }
    }
}

struct CheckView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        // Logika 3-langkah:
        // 1. Jika sedang loading, tampilkan Splash Screen.
        if authService.isLoading {
            SplashScreenView()
        }
        // 2. Jika sudah tidak loading DAN terotentikasi, tampilkan Home.
        else if authService.isAuthenticated {
            HomeView()
        }
        // 3. Jika sudah tidak loading DAN TIDAK terotentikasi, tampilkan Login.
        else {
            LoginView()
        }
    }
}
