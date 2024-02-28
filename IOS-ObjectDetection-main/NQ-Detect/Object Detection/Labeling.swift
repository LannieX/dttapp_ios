import Foundation
import SwiftUI

class Labeling{
    
    private var labelColors: [String: CGColor] = [:] // เก็บสีสำหรับแต่ละบล็อก
    
    
    init(){
        self.labelColors = self.generateLabelColors() // สร้าง dictionary เพื่อเก็บคู่ label-color
    }
    
    func labelImage(image:UIImage,observations:[ProcessedObservation]) -> UIImage?{ // ฟังก์ชันหลักสำหรับบล็อกบนรูปภาพ
        
        UIGraphicsBeginImageContext(image.size) // เตรียมการวาด

        image.draw(at: CGPoint.zero) // วาดรูปภาพต้นฉบับ
        
        let context = UIGraphicsGetCurrentContext()! // ดึง context ปัจจุบันมาใช้งาน
        
        
        for observation in observations{ // วนลูปแต่ละ observation (กล่องและป้ายกำกับ)
            let labelColor = labelColors[observation.label]! // ดึงสีของฉลากจาก dictionary
            let label = observation.label + " " + String(format:"%.1f",observation.confidence*100)+"%" // สร้างข้อความสำหรับฉลาก พร้อมเปอร์เซ็นต์ความมั่นใจ
            let boundingBox = observation.boundingBox // ดึงข้อมูล bounding box
            
            self.drawBox(context: context, bounds: boundingBox, color: labelColor) // วาดกล่องสำหรับฉลาก
            
            let textBounds = getTextRect(bigBox: boundingBox) // คำนวณตำแหน่งสำหรับกล่องข้อความ
            
            self.drawTextBox(context: context, drawText: label, bounds: textBounds, color: labelColor) // วาดกล่องข้อความ
            
        }
        
        let myImage = UIGraphicsGetImageFromCurrentImageContext() // บันทึก context เป็น UIImage ใหม่
        UIGraphicsEndImageContext()
        
        return myImage // ส่งคืนรูปภาพที่มีกล่องข้อความ
    }
    
    
    func drawBox(context:CGContext, bounds:CGRect, color:CGColor){ // ฟังก์ชันสำหรับวาดกล่อง bounding box
        context.setStrokeColor(color) // กำหนดสีของเส้นขอบ
        context.setLineWidth(bounds.height*0.01) // กำหนดความกว้างของเส้นขอบ
        context.addRect(bounds) // เพิ่มรูปสี่เหลี่ยมผืนผ้าลง context
        context.drawPath(using: .stroke) // วาดเส้นขอบ
    }
    func getTextRect(bigBox:CGRect) -> CGRect{ // ฟังก์ชันคำนวณตำแหน่งกล่องข้อความ
        let width = bigBox.width*0.45 //ความกว้างของกล่องข้อความ
        let height = bigBox.height*0.08 //ความสูงของกล่องข้อความ
        return CGRect(x: bigBox.minX, y: bigBox.minY - height, width: width, height: height) // ตำแหน่งกล่องข้อความจะอยู่เหนือ bounding box
    }
    func drawTextBox(context:CGContext ,drawText text: String, bounds:CGRect ,color:CGColor) { // ฟังก์ชันวาดกล่องข้อความ
        
        //กล่องข้อความ
        context.setFillColor(color)
        context.addRect(bounds)
        context.drawPath(using: .fill)
        
        //ข้อความ
        let textColor = UIColor.white
        let textFont = UIFont(name: "Helvetica Bold", size: bounds.height*0.45)!
        
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor
        ] as [NSAttributedString.Key : Any]
        
        text.draw(in: bounds.offsetBy(dx: bounds.width*0.05, dy: bounds.height*0.05), withAttributes: textFontAttributes) //วาดกล่องข้อความบน context
        
    }
    //รายการที่รองรับ
    let labels = ["person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"]
    
    func generateLabelColors() -> [String: CGColor] { // ฟังก์ชันสำหรับสร้าง dictionary เก็บคู่ label-color
        var labelColor: [String: CGColor] = [:]
        
        for i in 0...79 { //สุ่มสีของบล็อก object
            let color = UIColor(red: CGFloat.random(in: 0...1), green: CGFloat.random(in: 0...1), blue: CGFloat.random(in: 0...1), alpha: 1)
            labelColor[self.labels[i]] = color.cgColor
        }
        
        return labelColor
    }
    
}

