//
//  PhotoOperations.swift
//  ClassicPhotos
//
//  Created by neal on 2017/9/1.
//  Copyright © 2017年 neal. All rights reserved.
//

import UIKit
// 图片下载状态
enum PhotoRecordState {
    case New, Downloaded, Filtered, Failed
}

class PhotoRecord {
    let name: String
    let url: URL
    var state = PhotoRecordState.New
    var image = UIImage(named: "Placeholder")
    
    
    init(name: String , url: URL) {
        self.name = name
        self.url = url
    }
}


class PendingOperations {
    lazy var downloadsInProgres = [IndexPath:Operation]()
    lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var filtrationsInProgress = [IndexPath:Operation]()
    lazy var filtrationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Image Filtration queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
}

class ImageDownloader: Operation {
    let photoRecord:PhotoRecord
    
    init(photoRecord: PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {
        if isCancelled {
            return;
        }
        
        do {
            let imageData = try Data(contentsOf: photoRecord.url)
            
            if self.isCancelled {
                return
            }
            
            if imageData.count > 0 {
                photoRecord.image = UIImage(data: imageData)
                photoRecord.state = .Downloaded
            }else {
                photoRecord.state = .Failed
                photoRecord.image = UIImage(named: "Failed")
            }
            
        } catch let error as NSError {
            print(error.domain)
        }
    }
}

class ImageFiltration: Operation {
    let photoRecord : PhotoRecord
    
    init(photoRecord: PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    func applySepiaFilter(image:UIImage) -> UIImage? {
        let inputImage = CIImage(data: UIImagePNGRepresentation(image)!)
        
        if isCancelled {
            return nil
        }
        
        let context = CIContext(options:nil)
        let filter = CIFilter(name: "CISepiaTone")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(0.8, forKey: "inputIntensity")
        
        if isCancelled {
            return nil
        }
        
        
        if let outputImage = filter?.outputImage,
            let outImage = context.createCGImage(outputImage, from: outputImage.extent)
        {
            return UIImage(cgImage: outImage)
        }else {
            return nil
        }
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        if self.photoRecord.state != .Downloaded {
            return
        }
        
        if let image = photoRecord.image,
            let filteredImage = applySepiaFilter(image: image)
        {
            photoRecord.image = filteredImage
            photoRecord.state = .Filtered
        }
    }
}

