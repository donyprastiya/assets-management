//
//  LaporGangguanView.swift
//  Assets Management
//
//  Created by Dony on 07/07/25.
//

import SwiftUI
import AVFoundation

// MARK: - Main View
struct LaporGangguanView: View {
    @State private var isShowingManualInputSheet = false
    @State private var isTorchOn = false
    @State private var isScanning = true
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var navigateToResult = false
    @EnvironmentObject var viewRouter: ViewRouter
    
    
    var body: some View {
        ZStack {
            // Layer 1: Tampilan kamera dari scanner
            QRCodeScannerLaporView(
                isTorchOn: $isTorchOn,
                isScanning: $isScanning,
                showAlert: $showAlert,
                alertTitle: $alertTitle,
                alertMessage: $alertMessage,
                navigateToResult: $navigateToResult
            )
            .ignoresSafeArea()
            VStack {
                HStack {BackButtonLG()
                    Spacer()
                    FlashButtonLG(isTorchOn: $isTorchOn)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Label petunjuk di tengah
                Text("Arahkan kamera ke kode QR")
                    .padding(12)
                    .background(.thinMaterial)
                    .cornerRadius(10)
                    .padding(.top)
                
                Spacer()
                
                // "Jendela" atau area pemindaian QR
                // [PERBAIKAN] Menggunakan komponen yang sudah diganti namanya
                QRScannerOverlayLG()
                    .padding(.bottom, 40)
                
                Spacer()
                
                // Bagian Footer: Tombol input manual
                Button(action: {
                    Storage.saveString("1", forKey: "isManual")
                    print("isManual flag set to 1")
                    navigateToResult = true
                }) {
                    Text("Laporkan Manual")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(hex: BaseEnv.baseColor))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            
            // NavigationLink yang tidak terlihat untuk navigasi terprogram setelah scan
            NavigationLink(
                destination: LaporGangguanResultView(),
                isActive: $navigateToResult
            ) {
                EmptyView()
            }
        }
        .alert(alertTitle, isPresented: $showAlert, actions: {
            Button("OK", role: .cancel) {
                isScanning = true
            }
        }, message: {
            Text(alertMessage)
        })
        .navigationBarBackButtonHidden(true)
        .onAppear {
            isScanning = true
            // Membuat navigation bar menjadi transparan
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        .onDisappear {
            isScanning = false
            // Mengembalikan tampilan navigation bar ke default
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - UI Components (diberi akhiran LG untuk menghindari konflik)

struct BackButtonLG: View {
    @EnvironmentObject var viewRouter: ViewRouter

    var body: some View {
        Button(action: {
            viewRouter.dismiss()
        }) {
            Image(systemName: "arrow.left")
                .font(.title2.weight(.semibold))
                .padding(12)
                .background(.thinMaterial)
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct FlashButtonLG: View {
    @Binding var isTorchOn: Bool
    
    var body: some View {
        Button(action: {
            isTorchOn.toggle()
        }) {
            Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.title2.weight(.semibold))
                .padding(12)
                .background(.thinMaterial)
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct QRScannerOverlayLG: View {
    var body: some View {
        Image("ic_scan_border")
            .resizable()
            .scaledToFit()
            .frame(width: 250, height: 250)
    }
}

// MARK: - QR Code Scanner (UIViewControllerRepresentable)

struct QRCodeScannerLaporView: UIViewControllerRepresentable {

    @Binding var isTorchOn: Bool
    @Binding var isScanning: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var navigateToResult: Bool
    

    func makeUIViewController(context: Context) -> ScannerViewLaporController {
        let scannerViewController = ScannerViewLaporController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewLaporController, context: Context) {
        if isScanning {
            uiViewController.resumeScanning()
        } else {
            uiViewController.pauseScanning()
        }
        
        uiViewController.toggleTorch(isOn: isTorchOn)
    }
    
    func makeCoordinator() -> CoordinatorLaporGangguan {
        CoordinatorLaporGangguan(parent: self)
    }

    class CoordinatorLaporGangguan: NSObject, ScannerViewLaporControllerDelegate {
        var parent: QRCodeScannerLaporView
        
        init(parent: QRCodeScannerLaporView) {
            self.parent = parent
        }
        
        func didFind(code: String) {
            DispatchQueue.main.async { self.parent.isScanning = false }
            
            guard let data = code.data(using: .utf8) else {
                showInvalidFormatAlert(); return
            }
            
            if let payload = try? JSONDecoder().decode(QRCodePayload.self, from: data) {
                // SUKSES: Format JSON valid, sekarang panggil API aset
                Task {
                    let success = await fetchAndSaveAssetData(type: "serial_number", value: payload.value)
                    
                    // Update UI di main thread setelah API call selesai
                    await MainActor.run {
                        if success {
                            self.parent.navigateToResult = true
                        } else {
                            self.parent.alertTitle = "Gagal"
                            self.parent.alertMessage = "Data aset tidak dapat ditemukan di server."
                            self.parent.showAlert = true
                        }
                    }
                }
            } else {
                // GAGAL: Format JSON tidak valid
                showInvalidFormatAlert()
            }
        }
        
        private func fetchAndSaveAssetData(type: String, value: String) async -> Bool {
            guard var urlComponents = URLComponents(string: "\(BaseEnv.baseURL)/asset") else { return false }
            urlComponents.queryItems = [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "value", value: value)
            ]
            guard let url = urlComponents.url else { return false }
            
            guard let token = await AuthenticationService.shared.getValidAccessToken() else { return false }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return false
                }
                let assetSummary = try JSONDecoder().decode(AssetSummary.self, from: data)
                
                // Simpan data yang diperlukan ke StorageService
                Storage.saveString(assetSummary.id, forKey: "laporGangguan_assetId")
                Storage.saveString(assetSummary.name ?? "", forKey: "laporGangguan_name")
                Storage.saveString(assetSummary.serialNumber ?? "", forKey: "laporGangguan_serialNumber")
                Storage.saveString(assetSummary.categoryId ?? "", forKey: "laporGangguan_categoryId")
                Storage.saveString(assetSummary.categoryName ?? "", forKey: "laporGangguan_categoryName")
                Storage.saveString(assetSummary.directoryId ?? "", forKey: "laporGangguan_directoryId")
                Storage.saveString(assetSummary.directoryFullName ?? "", forKey: "laporGangguan_directoryName")
                Storage.saveString("0", forKey: "isManual")
                
                print("Data aset untuk lapor gangguan berhasil disimpan.")
                
                
                return true
            } catch {
                print("Gagal fetch atau decode data aset: \(error)")
                return false
            }
        }
        
        private func showInvalidFormatAlert() {
            DispatchQueue.main.async {
                self.parent.alertTitle = "Format Tidak Valid"
                self.parent.alertMessage = "Kode QR ini tidak memiliki format yang benar."
                self.parent.showAlert = true
            }
        }
    }
}

// MARK: - Delegate Protocol and Scanner UIViewController

protocol ScannerViewLaporControllerDelegate: AnyObject {
    func didFind(code: String)
}

class ScannerViewLaporController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: ScannerViewLaporControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        resumeScanning()
    }

    func failed() {
        // Handle failure appropriately
    }
    
    // Fungsi untuk memulai/melanjutkan sesi kamera
    func resumeScanning() {
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    // Fungsi untuk menghentikan sesi kamera
    func pauseScanning() {
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func toggleTorch(isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didFind(code: stringValue)
        }
    }
}


#Preview {
    NavigationView {
        LaporGangguanView()
            .environmentObject(ViewRouter()) // Sediakan ViewRouter untuk preview
    }
}
