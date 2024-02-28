import SwiftUI
import Photos

// โครงสร้าง PhotoView เป็น View
struct PhotoView: View {

    // ตัวแปร image เป็น Binding ของ Image? (ออปชันแนล Image)
    // อัพเดทค่า image จะอัพเดท View โดยอัตโนมัติ
    @Binding var image: Image?

    // ดึง dismiss action จาก Environment
    // ใช้เพื่อปิด View
    @Environment(\.dismiss) var dismiss

    // เนื้อหาของ View
    var body: some View {

        // จัดกลุ่ม View ย่อย
        Group {

            // ตรวจสอบว่า image มีค่าหรือไม่
            if let image = image {

                // วาง View ซ้อนกันแนวตั้ง
                VStack {

                    // แสดงรูปภาพ
                    // ปรับขนาดให้พอดีกับพื้นที่
                    image
                        .resizable()
                        .scaledToFit()

                    // ข้อความแจ้งเตือนว่ารูปภาพถูกบันทึก
                    Text("รูปภาพถูกบันทึกลงในคลังรูปภาพของคุณแล้ว")
                        .font(.title2)
                        .foregroundColor(.white)

                    // ปุ่มสำหรับปิด View
                    // แสดงไอคอนลูกศรย้อนกลับ
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.backward")
                    }
                    .padding(25) // ขยายระยะห่างภายในปุ่ม
                    .foregroundColor(.blue) // กำหนดสีตัวอักษร
                    .background(Color.black) // กำหนดสีพื้นหลัง
                    .cornerRadius(20) // มุมโค้งมน
                    .frame(width: 350) // กำหนดความกว้าง

                }

            } else {

                // แสดง ProgressView รอโหลดรูปภาพ
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // ขยายขนาดเต็มหน้าจอ
        .ignoresSafeArea() // เพิกเฉยต่อ Safe Area แสดงเต็มพื้นที่
        .background(Color.pink) // กำหนดสีพื้นหลัง
        .navigationTitle("รูปภาพ") // ตั้งชื่อ Title Bar
        .navigationBarTitleDisplayMode(.inline) // แสดง Title Bar แบบ inline
    }
}
