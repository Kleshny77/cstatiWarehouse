//
//  UIImage+Compression.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import UIKit

extension UIImage {
    
    func compressed(quality: CGFloat = 0.7, maxDimension: CGFloat = 2048) -> Data? {
        let resized = resized(maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }
    
    func resized(maxDimension: CGFloat) -> UIImage {
        let size = self.size
        
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func estimatedCompressedSize(quality: CGFloat = 0.7, maxDimension: CGFloat = 2048) -> Double {
        guard let data = compressed(quality: quality, maxDimension: maxDimension) else {
            return 0
        }
        return Double(data.count) / 1_048_576 // Байты в МБ
    }
    
    func thumbnail(size: CGFloat = 200) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { context in
            let imageSize = self.size
            let scale = max(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            
            self.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
