import SwiftUI

struct CameraView: View { // โครงสร้าง CameraView เป็น View
    @StateObject private var model = DataModel() // ใช้ StateObject เก็บข้อมูลที่ใช้ร่วมกันใน View
 
    private static let barHeightFactor = 0.10 // ค่าคงที่สำหรับอัตราส่วนความสูงของแถบ
    
    @State private var isImageTaken = false // ตัวแปร State สำหรับสถานะการถ่ายภาพ
    
    var body: some View {
        
        NavigationView {
            GeometryReader { geometry in // GeometryReader เพื่อดึงขนาดของ View
                ViewfinderView(image:  $model.viewfinderImage ) // Viewfinder แสดงภาพจากกล้อง
                    
                    // ซ้อนทับแถบสีดำโปร่งแสงด้านบน
                    .overlay(alignment: .top) {
                        ZStack{
                            Color.black
                                .opacity(0.7)
                                .frame(height: geometry.size.height * Self.barHeightFactor)
                        }
                    }
                    // ซ้อนทับ View ของปุ่มด้านล่าง
                    .overlay(alignment: .bottom) {
                        buttonsView()
                            .frame(height: geometry.size.height * (Self.barHeightFactor+0.05))
                            .background(.black.opacity(0.7))
                    }
                
                    // ซ้อนทับพื้นที่โปร่งใสตรงกลาง
                    // ตั้งค่าการช่วยการเข้าถึง
                    .overlay(alignment: .center)  {
                        Color.clear
                            .frame(height: geometry.size.height * (1 - (Self.barHeightFactor * 2)))
                            .accessibilityElement()
                            .accessibilityLabel("View Finder")
                            .accessibilityAddTraits([.isImage])
                    }
                    // ตั้งค่าพื้นหลังเป็นสีดำ
                    .background(.black)
            }
            .task {
                // เริ่มต้นกล้องเมื่อ View ปรากฏ
                await model.camera.start()
            }
            // ตั้งค่าชื่อเรื่องและรูปแบบแถบนำทาง
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            
            // เพิกเฉยต่อ Safe Area Insets และซ่อนแถบสถานะ
            .ignoresSafeArea()
            .statusBar(hidden: true)
            
            // Sheet แสดงรูปถ่ายที่ถ่าย
            .sheet(isPresented: self.$isImageTaken) {
                PhotoView(image: $model.thumbnailImage).onAppear(){
                    model.camera.isPreviewPaused = true  // หยุดการแสดงตัวอย่างชั่วคราว
                }.onDisappear(){
                    // เริ่มการแสดงตัวอย่างใหม่และล้างรูปย่อ
                    model.camera.isPreviewPaused = false
                    model.thumbnailImage = nil
                    
                }
                // ปิดใช้งานตัวจับเวลาว่างระบบ
            }.onAppear(){
                UIApplication.shared.isIdleTimerDisabled = true
            }.onDisappear(){
                UIApplication.shared.isIdleTimerDisabled = false
            }
            
        }
    }
    // กำหนดเค้าโครงและการทำงานของ View ปุ่ม
    private func buttonsView() -> some View {
        HStack() {
            // ปุ่มสำหรับถ่ายภาพและสลับสถานะถ่ายภาพ
            Button {
                model.camera.takePhoto()
                self.isImageTaken.toggle()
            } label: {
                Label {
                    Text("Take Photo")
                } icon: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                            .frame(width: 62, height: 62)
                        Circle()
                            .fill(.blue)
                            .frame(width: 50, height: 50)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .center)
            // ปุ่มสำหรับสลับกล้อง
            Button {
                model.camera.switchCaptureDevice()
            } label: {
                Label("Switch Camera", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundColor(.blue)
            }.frame(maxWidth: .leastNormalMagnitude, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .padding()
    }
    
}
