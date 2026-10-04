//
//  DatabaseAsetView.swift
//  Assets Management
//
//  Created by Dony on 07/07/25.
//

import SwiftUI
import AVFoundation

// MARK: - Main View
struct DatabaseAsetView: View {
    // State untuk mengontrol presentasi bottom sheet
    @State private var isShowingManualInputSheet = false
    // State untuk menyimpan hasil scan atau input manual
    @State private var scannedCode: String?
    // State untuk mengontrol lampu flash
    @State private var isTorchOn = false
    // State untuk mengontrol apakah kamera sedang aktif memindai
    @State private var isScanning = true
    
    // State untuk mengelola alert
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var navigateToResult = false
    
    
    var body: some View {
        ZStack {
            // Layer 1: Tampilan kamera dari scanner
            // Kita gunakan representable untuk menjembatani dengan AVFoundation
            QRCodeScannerView(
                            isTorchOn: $isTorchOn,
                            isScanning: $isScanning,
                            showAlert: $showAlert,
                            alertTitle: $alertTitle,
                            alertMessage: $alertMessage,
                            navigateToResult: $navigateToResult
                        )
                .ignoresSafeArea()
            
            // Layer 2: Overlay UI di atas kamera
            VStack {
                // Bagian Header: Tombol Kembali dan Flash
                HStack {
                    // Tombol kembali kustom
                    BackButton()
                    
                    Spacer()
                    
                    // Tombol Flash
                    FlashButton(isTorchOn: $isTorchOn)
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
                QRScannerOverlay()
                    .padding(.bottom, 40)
                
                Spacer()
                
                // Bagian Footer: Tombol input manual
                Button(action: {
                    isScanning = false
                    isShowingManualInputSheet = true
                }) {
                    Text("Cari Serial Number Manual")
                        .font(.custom("Inter18pt-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color(hex: BaseEnv.baseColor)) // Warna biru tombol sesuai gambar
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            NavigationLink(
                        destination: DatabaseAsetResultView(), // Panggil view tujuan tanpa parameter
                        isActive: $navigateToResult
            ) {
                EmptyView()
            }
        }
        // Menampilkan alert jika ada hasil scan
        .alert(alertTitle, isPresented: $showAlert, actions: {
                    Button("OK", role: .cancel) {
                        // Saat OK ditekan, aktifkan kembali pemindaian
                        isScanning = true
                    }
        }, message: {
            Text(alertMessage)
        })
        // Menampilkan bottom sheet untuk input manual
        .sheet(isPresented: $isShowingManualInputSheet, onDismiss: {
            isScanning = true
        }) {
            // Cek jika versi iOS adalah 16.4 atau lebih baru untuk menggunakan .fit
            if #available(iOS 16.4, *) {
                ManualInputSheet(navigateToResult: $navigateToResult)                // .fit akan membuat sheet pas dengan ukuran kontennya.
                    .presentationDetents([.height(220), .medium])
            }
            // Fallback untuk iOS 16.0 - 16.3
            else if #available(iOS 16.0, *) {
                ManualInputSheet(navigateToResult: $navigateToResult)                // .medium adalah fallback yang baik, sheet akan bisa di-resize.
                    .presentationDetents([.medium])
            } else {
                // Fallback untuk iOS 15 dan di bawahnya, akan menjadi sheet default.
                ManualInputSheet(navigateToResult: $navigateToResult)            }
        }
        .navigationBarBackButtonHidden(true)
        
        // Gunakan toolbar untuk menempatkan tombol kembali kustom (sudah ada di dalam VStack)
        // Kita hanya perlu memastikan bar-nya transparan.
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
            // Mengembalikan tampilan navigation bar ke default saat meninggalkan view ini
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - UI Components

struct BackButton: View {
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

struct FlashButton: View {
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

struct QRScannerOverlay: View {
    var body: some View {
        Image("ic_scan_border")
            .resizable()
            .scaledToFit()
            .frame(width: 250, height: 250)
    }
}
// MARK: - Bottom Sheet View

struct ManualInputSheet: View {
    @EnvironmentObject var viewRouter: ViewRouter
    @State private var serialNumber = ""
    @Environment(\.dismiss) var dismiss
    @Binding var navigateToResult: Bool
    
    var body: some View {
        VStack(spacing: 20)
        {
            Text("Masukan Serial Number")
                .font(.custom("Inter18pt-SemiBold", size: 20))
                .foregroundColor(.black)
            
            TextField("Contoh: SN123456789", text: $serialNumber)
                .font(.custom("Inter18pt-Regular", size: 14))
                .foregroundColor(.black) // Mengatur warna teks yang diketik menjadi hitam
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
            
            Button(action: {
                print("Mencari serial number: \(serialNumber)")
                // TODO: Tambahkan logika pencarian API di sini
                Storage.saveString("serial_number", forKey: "lastScannedType")
                Storage.saveString(serialNumber, forKey: "lastScannedValue")
//                viewRouter.show(.databaseAsetResult)
                DispatchQueue.main.async {
                    self.navigateToResult = true
                    dismiss()
                }
            
            }) {
                Text("Cari")
                    .font(.custom("Inter18pt-SemiBold", size: 14))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color(hex: BaseEnv.baseColor))
                    .cornerRadius(10)
            }
            // Spacer dihapus agar VStack "memeluk" kontennya.
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.white)
    }
}
// MARK: - QR Code Scanner (UIViewControllerRepresentable)

struct QRCodeScannerView: UIViewControllerRepresentable {

    @Binding var isTorchOn: Bool
    @Binding var isScanning: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var navigateToResult: Bool
    

    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerViewController = ScannerViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // Kontrol sesi kamera dari SwiftUI
        if isScanning {
            uiViewController.resumeScanning()
        } else {
            uiViewController.pauseScanning()
        }
        
        // Kontrol flash tetap sama
        uiViewController.toggleTorch(isOn: isTorchOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: QRCodeScannerView
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func didFind(code: String) {
            @EnvironmentObject var viewRouter: ViewRouter
            // Hentikan pemindaian agar tidak memproses berulang kali
            DispatchQueue.main.async {
                self.parent.isScanning = false
            }
            
            // Coba decode string hasil scan menjadi format JSON yang diharapkan
            guard let data = code.data(using: .utf8) else {
                showInvalidFormatAlert()
                return
            }
            
            let decoder = JSONDecoder()
            if let payload = try? decoder.decode(QRCodePayload.self, from: data) {
                // SUKSES: Format JSON valid
                // Simpan value ke StorageService
                Storage.saveString("serial_number", forKey: "lastScannedtype")
                Storage.saveString(payload.value, forKey: "lastScannedValue")
                DispatchQueue.main.async {
                    self.parent.navigateToResult = true
                    //                                    self.parent.viewRouter.show(.databaseAsetResult)
                }
            } else {
                // GAGAL: Format JSON tidak valid
                showInvalidFormatAlert()
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

protocol ScannerViewControllerDelegate: AnyObject {
    func didFind(code: String)
}

class ScannerViewController: UIViewController {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: ScannerViewControllerDelegate?

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
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
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
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            // Panggil delegate tanpa menghentikan sesi di sini
            delegate?.didFind(code: stringValue)
        }
    }
}

// MARK: - Preview
struct DatabaseAsetView_Previews: PreviewProvider {
    static var previews: some View {
        // Bungkus dengan NavigationView untuk melihat judul dan tombol kembali
        NavigationView {
            DatabaseAsetView()
        }
    }
}

