import SwiftUI

struct ViewfinderView: View { // โครงสร้าง ViewfinderView เป็น View
    
    // ตัวแปร image เป็น Binding ของ Image? (ออปชันแนล Image)
        // อัพเดทค่า image จะอัพเดท View โดยอัตโนมัติ
    @Binding var image: Image?
    
    var body: some View {
        GeometryReader { geometry in // ใช้ GeometryReader เพื่อดึงขนาดของ View
            if let image = image { // ตรวจสอบว่า image มีค่าหรือไม่
                
                // แสดงรูปภาพ
                // ปรับขนาดให้เต็มพื้นที่
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct ViewfinderView_Previews: PreviewProvider {
    static var previews: some View {
        ViewfinderView(image: .constant(Image(systemName: "pencil")))
    }
}
