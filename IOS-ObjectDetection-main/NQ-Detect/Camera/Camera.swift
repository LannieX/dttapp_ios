import AVFoundation
import Vision
import CoreImage
import UIKit


//ตัวแปรการทำงานกล้อง
class Camera: NSObject {
    private let captureSession = AVCaptureSession() //สร้างตัวแปรสำหรับการจัดการ session การทำงานของกล้อง
    private var isCaptureSessionConfigured = false //ป้ายสถานะเพื่อติดตามว่าเซสชันกล้องได้รับการกำหนดค่าแล้วหรือไม่
    private var isSelectingLabel = false
    private var deviceInput: AVCaptureDeviceInput? //อินพุตอุปกรณ์กล้องปัจจุบัน
    private var photoOutput: AVCapturePhotoOutput? //เอาต์พุตภาพถ่าย
    private var videoOutput: AVCaptureVideoDataOutput? //เอาต์พุตข้อมูลวิดีโอ
    private var sessionQueue: DispatchQueue! //คิวสำหรับทำงานกับเซสชันกล้อง
    
    private var currentObservations: [VNObservation]?
    private var viewfinderImageView: UIImageView!
    private var viewfinderImage: UIImage?

    private var allCaptureDevices: [AVCaptureDevice] { //เก็บรายการอุปกรณ์กล้องทั้งหมด
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInDualWideCamera], mediaType: .video, position: .unspecified).devices
    }
    
    private var frontCaptureDevices: [AVCaptureDevice] { //กรองเฉพาะอุปกรณ์กล้องหน้า
        allCaptureDevices
            .filter { $0.position == .front }
    }
    
    private var backCaptureDevices: [AVCaptureDevice] { //กรองเฉพาะอุปกรณ์กล้องหลัง
        allCaptureDevices
            .filter { $0.position == .back }
    }
    
    private var captureDevices: [AVCaptureDevice] { //เก็บอุปกรณ์กล้องที่พร้อมใช้งาน (เชื่อมต่อและไม่ถูกระงับ)
        var devices = [AVCaptureDevice]()
        #if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
        devices += allCaptureDevices
        #else
        if let backDevice = backCaptureDevices.first {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first {
            devices += [frontDevice]
        }
        #endif
        return devices
    }
    
    private var availableCaptureDevices: [AVCaptureDevice] { // อุปกรณ์กล้องที่กำลังใช้งาน
        captureDevices
            .filter( { $0.isConnected } )
            .filter( { !$0.isSuspended } )
    }
    
    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice = captureDevice else { return }
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
    }
    
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    var isUsingFrontCaptureDevice: Bool { //บอกสถานะว่าใช้อุปกรณ์กล้องหน้าหรือไม่
        guard let captureDevice = captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }
    
    var isUsingBackCaptureDevice: Bool { //บอกสถานะว่าใช้อุปกรณ์กล้องหลังหรือไม่
        guard let captureDevice = captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }

    private var addToPhotoStream: ((AVCapturePhoto) -> Void)? //ฟังก์ชันสำหรับส่งภาพถ่ายที่ถ่ายใหม่
    
    private var addToPreviewStream: ((CIImage) -> Void)? //ฟังก์ชันสำหรับส่งข้อมูลภาพสด
    
    var isPreviewPaused = false //บอกสถานะว่าการแสดงภาพสดถูกหยุดชั่วคราว
    
    lazy var previewStream: AsyncStream<CIImage> = { //สตรีมข้อมูลภาพสดแบบอะซิงค์
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()
    
    lazy var photoStream: AsyncStream<AVCapturePhoto> = { //สตรีมข้อมูลภาพถ่ายแบบอะซิงค์
        AsyncStream { continuation in
            addToPhotoStream = { photo in
                continuation.yield(photo)
            }
        }
    }()
        
    override init() { //ฟังก์ชันเริ่มต้นคลาส Camera
        super.init()
        initialize()
    }
    
    private func initialize() { //เรียกใช้ฟังก์ชันกำหนดค่าเริ่มต้น
        sessionQueue = DispatchQueue(label: "session queue")
        
        captureDevice = availableCaptureDevices.first ?? AVCaptureDevice.default(for: .video)
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateForDeviceOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void) { //กำหนดค่าเซสชันกล้อง
        
        var success = false
        
        self.captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }
        
        guard
            let captureDevice = captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            print("Failed to obtain video input.")
            return
        }
        
        let photoOutput = AVCapturePhotoOutput()
                        
        captureSession.sessionPreset = AVCaptureSession.Preset.photo

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
  
        guard captureSession.canAddInput(deviceInput) else {
           print("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(photoOutput) else {
            print("Unable to add photo output to capture session.")
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            print("Unable to add video output to capture session.")
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        updateVideoOutputConnection()
        
        isCaptureSessionConfigured = true
        
        success = true
    }
    
    private func checkAuthorization() async -> Bool { //ตรวจสอบสิทธิ์การเข้าถึงกล้อง
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized.")
            return true
        case .notDetermined:
            print("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            print("Camera access denied.")
            return false
        case .restricted:
            print("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? { //สร้างอินพุตอุปกรณ์กล้อง
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            print("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) { //อัปเดตเซสชันสำหรับอุปกรณ์กล้องใหม่
        guard isCaptureSessionConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }
        
        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        
        updateVideoOutputConnection()
    }
    
    private func updateVideoOutputConnection() { //อัปเดตการเชื่อมต่อข้อมูลวิดีโอ
        if let videoOutput = videoOutput, let videoOutputConnection = videoOutput.connection(with: .video) {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored = isUsingFrontCaptureDevice
            }
        }
    }
    
    func start() async { //เริ่มการทำงานของกล้อง
        let authorized = await checkAuthorization()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }
        
        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                }
            }
            return
        }
        
        sessionQueue.async { [self] in
            self.configureCaptureSession { success in
                guard success else { return }
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() { //หยุดการทำงานของกล้อง
        guard isCaptureSessionConfigured else { return }
        
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func switchCaptureDevice() { //สลับไปใช้อุปกรณ์กล้องอีกตัว
        if let captureDevice = captureDevice, let index = availableCaptureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % availableCaptureDevices.count
            self.captureDevice = availableCaptureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }
    }

    private var deviceOrientation: UIDeviceOrientation { //ติดตามทิศทางของอุปกรณ์
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
    
    @objc
    func updateForDeviceOrientation() { // อัปเดตการทำงานตามทิศทางของอุปกรณ์ (ยังไม่ได้ใช้งาน)
        //TODO: Figure out if we need this for anything.
    }
    
    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        // แปลงทิศทางของอุปกรณ์เป็นทิศทางวิดีโอ
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
        }
    }
    
    func takePhoto() { //ถ่ายภาพ
        guard let photoOutput = self.photoOutput else { return }
        
        sessionQueue.async {
        
            var photoSettings = AVCapturePhotoSettings()

            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvailable ? .auto : .off
            photoSettings.isHighResolutionPhotoEnabled = true
            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
            }
            photoSettings.photoQualityPrioritization = .balanced
            
            if let photoOutputVideoConnection = photoOutput.connection(with: .video) {
                if photoOutputVideoConnection.isVideoOrientationSupported,
                    let videoOrientation = self.videoOrientationFor(self.deviceOrientation) {
                    photoOutputVideoConnection.videoOrientation = videoOrientation
                }
            }
            
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func handleLabelTap(gesture: UITapGestureRecognizer) {

        guard let observations = currentObservations as? [VNDetectedObjectObservation], observations.count > 0 else { return }

        // หา label ที่ถูกแตะ
        let location = gesture.location(in: viewfinderImageView)
        for observation in observations {
            if let boundingBox = observation.boundingBox.cgRectValue {
                if boundingBox.contains(location) {

                    // แปลง boundingBox ของ label ให้เป็น CGRect ในระบบพิกัดของภาพ
                    let imageRect = CGRect(origin: .zero, size: viewfinderImageView)
                    let scaledBoundingBox = observation.boundingBox.scaled(to: imageRect.size)

                    // ครอบตัดรูปภาพตาม boundingBox ของ label
                    guard let croppedImage = viewfinderImage.uiImage.cgImage?.cropping(to: scaledBoundingBox) else { return }

                    // บันทึกรูปภาพที่ครอบตัดแล้ว
                    UIImageWriteToSavedPhotosAlbum(UIImage(cgImage: croppedImage), self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
                    
                    // แสดงตัวอย่างรูปภาพที่ครอบตัด
                    let previewImage = UIImageView(frame: scaledBoundingBox)
                    previewImage.image = UIImage(cgImage: croppedImage)
                    previewImage.layer.borderColor = UIColor.red.cgColor
                    previewImage.layer.borderWidth = 2
                    viewfinderImageView.addSubview(previewImage)

                    // ซ่อนตัวอย่างรูปภาพหลังจาก 1 วินาที
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        previewImage.removeFromSuperview()
                    }

                    break
                }
            }
        }
    }


    
    
}

extension Camera: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        //รับข้อมูลภาพถ่ายที่ถ่ายใหม่
        
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        addToPhotoStream?(photo)
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        // รับข้อมูลภาพสด
        
        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(deviceOrientation) {
            connection.videoOrientation = videoOrientation
        }

        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

fileprivate extension UIScreen { // กำหนดฟังก์ชัน orientation เพื่อรับทิศทางของหน้าจอ

    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}

