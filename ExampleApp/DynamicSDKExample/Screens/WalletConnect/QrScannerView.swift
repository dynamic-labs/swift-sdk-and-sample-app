import SwiftUI
import AVFoundation

struct QrScannerView: View {
  let onScanned: (String) -> Void
  let onDismiss: () -> Void

  @State private var hasCameraPermission = false

  var body: some View {
    ZStack {
      if hasCameraPermission {
        CameraPreview(onScanned: onScanned)
          .ignoresSafeArea()

        // Scan overlay
        GeometryReader { geo in
          let size = min(geo.size.width, geo.size.height) * 0.65
          ZStack {
            Color.black.opacity(0.5)
              .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 16)
              .frame(width: size, height: size)
              .blendMode(.destinationOut)
          }
          .compositingGroup()

          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white, lineWidth: 2)
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }

        VStack {
          Spacer()
          Text("Scan WalletConnect QR Code")
            .foregroundColor(.white)
            .font(.headline)
            .padding(.bottom, 100)
        }
      } else {
        VStack(spacing: 16) {
          Text("Camera permission is required to scan QR codes")
          Button("Grant Permission") {
            requestCameraAccess()
          }
        }
        .padding()
      }

      // Close button
      VStack {
        HStack {
          Spacer()
          Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
              .font(.title)
              .foregroundColor(.white)
              .shadow(radius: 4)
          }
          .padding()
        }
        Spacer()
      }
    }
    .onAppear { requestCameraAccess() }
  }

  private func requestCameraAccess() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      hasCameraPermission = true
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async { hasCameraPermission = granted }
      }
    default:
      hasCameraPermission = false
    }
  }
}

// MARK: - Camera Preview (UIKit bridge)

private struct CameraPreview: UIViewControllerRepresentable {
  let onScanned: (String) -> Void

  func makeUIViewController(context: Context) -> CameraScannerViewController {
    let vc = CameraScannerViewController()
    vc.onScanned = onScanned
    return vc
  }

  func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {}
}

private class CameraScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  var onScanned: ((String) -> Void)?
  private var captureSession: AVCaptureSession?
  private var hasScanned = false

  override func viewDidLoad() {
    super.viewDidLoad()

    let session = AVCaptureSession()
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device) else { return }

    session.addInput(input)

    let output = AVCaptureMetadataOutput()
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    output.metadataObjectTypes = [.qr]

    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.frame = view.bounds
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)

    captureSession = session
    DispatchQueue.global(qos: .userInitiated).async {
      session.startRunning()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if let layer = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
      layer.frame = view.bounds
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    captureSession?.stopRunning()
  }

  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard !hasScanned,
          let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          let value = object.stringValue,
          value.hasPrefix("wc:") else { return }

    hasScanned = true
    onScanned?(value)
  }
}
