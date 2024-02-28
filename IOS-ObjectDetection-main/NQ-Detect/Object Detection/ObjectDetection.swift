import AVFoundation
import Vision
import CoreImage

class ObjectDetection{
    var detectionRequest:VNCoreMLRequest!
    var ready = false //ประกาศว่าโมเดลจะยังไม่พร้อมให้ใช้งาน
    
    init(){
        Task { self.initDetection() } //ใช้ task เพื่อเรียก init ในพื้นหลัง 
    }
    
    func initDetection(){
        do {
            let model = try VNCoreMLModel(for: yolov8n(configuration: MLModelConfiguration()).model) //โหลดโมเดล
            
            self.detectionRequest = VNCoreMLRequest(model: model) //สร้าง VNCore สำหรับโมเดล
            
            self.ready = true //ระบุว่าโมเดลพร้อมใช้งาน
            
        } catch let error {
            fatalError("failed to setup model: \(error)")
        }
    }
    
    func detectAndProcess(image:CIImage)-> [ProcessedObservation]{
        
        let observations = self.detect(image: image)
        
        let processedObservations = self.processObservation(observations: observations, viewSize: image.extent.size) //เรียก processedObservations เพื่อแปลงผลลัพธ์ให้เป็นข้อมูลที่ใช้งานได้
        
        return processedObservations //ส่งข้อมูลที่แปลงแล้ว
    }
    
    
    func detect(image:CIImage) -> [VNObservation]{
        
        let handler = VNImageRequestHandler(ciImage: image) //สร้าง VNImageRequestHandler สำหรับภาพ CiImage
        
        do{
            try handler.perform([self.detectionRequest]) //รัน VNCoreMLRequest
            let observations = self.detectionRequest.results!
            
            return observations //ส่งคืนผลลัพธ์ VNObservation
            
        }catch let error{
            fatalError("failed to detect: \(error)")
        }
        
    }
    
    
    func processObservation(observations:[VNObservation], viewSize:CGSize) -> [ProcessedObservation]{
       
        var processedObservations:[ProcessedObservation] = [] //สร้างอาร์เรย์ ProcessedObservation ว่าง
        
        for observation in observations where observation is VNRecognizedObjectObservation { //ลูปแต่ละ VNObservation (ถ้าเป็น VNRecognizedObjectObservation)
            
            let objectObservation = observation as! VNRecognizedObjectObservation
            
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(viewSize.width), Int(viewSize.height)) ////คำนวณตำแหน่งกล่อง Bounding Box จากข้อมูลที่ได้
            
            let flippedBox = CGRect(x: objectBounds.minX, y: viewSize.height - objectBounds.maxY, width: objectBounds.maxX - objectBounds.minX, height: objectBounds.maxY - objectBounds.minY)
            
            let label = objectObservation.labels.first!.identifier
            
            let processedOD = ProcessedObservation(label: label, confidence: objectObservation.confidence, boundingBox: flippedBox) //สร้าง ProcessedObservation ใหม่
            
            processedObservations.append(processedOD)  //เพิ่ม ProcessedObservation เข้าไปในอาร์เรย์
        }
        
        return processedObservations //ส่งคืนอาร์เรย์ ProcessedObservation
        
    }
    
}

struct ProcessedObservation{ //เก็บข้อมูลของอ็อบเจกต์ที่ตรวจพบ
    var label: String //label: ชื่อของอ็อบเจกต์
    var confidence: Float //confidence: ความมั่นใจในการตรวจพบ
    var boundingBox: CGRect //boundingBox: ตำแหน่งกล่อง Bounding Box
}
