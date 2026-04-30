# iOS Lazy Image Loading — Ленивая загрузка изображений

## Overview

Система ленивой загрузки изображений для iOS приложения с кэшированием, приоритизацией, предзагрузкой и оптимизацией памяти. Обеспечивает плавную прокрутку списков с изображениями и минимальное потребление памяти.

## Problems to Solve

### Current Issues
- ❌ Все изображения загружаются сразу
- ❌ Высокое потребление памяти
- ❌ Медленная прокрутка при большом количестве изображений
- ❌ Нет кэширования (повторные загрузки)
- ❌ Нет приоритизации (видимые vs невидимые)
- ❌ Нет placeholder'ов во время загрузки

### Target Solution
- ✅ Загрузка только видимых изображений
- ✅ Двухуровневое кэширование (memory + disk)
- ✅ Приоритизация видимых ячеек
- ✅ Отмена загрузки при скролле
- ✅ Предзагрузка следующих изображений
- ✅ Автоматическая очистка памяти
- ✅ Placeholder и индикатор загрузки
- ✅ Поддержка разных размеров (thumbnails)

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  SwiftUI View                       │
│  (AsyncImage / CachedAsyncImage)                    │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│            ImageLoader (Observable)                  │
│  - Load state management                            │
│  - Priority handling                                │
│  - Cancellation                                     │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│          ImageCacheService (Singleton)               │
│  - Memory cache (NSCache)                           │
│  - Disk cache (FileManager)                         │
│  - Download queue                                   │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│              URLSession                              │
│  - Network requests                                 │
│  - Download tasks                                   │
└─────────────────────────────────────────────────────┘
```

## Implementation

### 1. Image Cache Service

**`ios/cstatiWarehouse/Services/ImageCache/ImageCacheService.swift`**:

```swift
//
//  ImageCacheService.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import UIKit
import Foundation

final class ImageCacheService {
    
    // MARK: - Singleton
    
    static let shared = ImageCacheService()
    
    // MARK: - Properties
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let downloadQueue = OperationQueue()
    private var activeDownloads: [URL: ImageDownloadOperation] = [:]
    private let lock = NSLock()
    
    // MARK: - Configuration
    
    private let maxMemoryCacheSize: Int = 100 * 1024 * 1024 // 100 MB
    private let maxDiskCacheSize: Int = 500 * 1024 * 1024 // 500 MB
    private let maxConcurrentDownloads = 4
    
    // MARK: - Initialization
    
    private init() {
        // Setup memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = 100 // Max 100 images in memory
        
        // Setup disk cache directory
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Setup download queue
        downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
        downloadQueue.qualityOfService = .userInitiated
        
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Clean old cache on init
        cleanExpiredCache()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Load image with caching and priority
    func loadImage(
        from url: URL,
        priority: ImageLoadPriority = .normal,
        completion: @escaping (Result<UIImage, ImageCacheError>) -> Void
    ) -> ImageLoadTask {
        // Check memory cache first
        if let cachedImage = getFromMemoryCache(url: url) {
            completion(.success(cachedImage))
            return ImageLoadTask(url: url, cancel: {})
        }
        
        // Check disk cache
        if let cachedImage = getFromDiskCache(url: url) {
            // Store in memory cache for faster access
            storeInMemoryCache(image: cachedImage, url: url)
            completion(.success(cachedImage))
            return ImageLoadTask(url: url, cancel: {})
        }
        
        // Download from network
        return downloadImage(from: url, priority: priority, completion: completion)
    }
    
    /// Prefetch images (low priority background loading)
    func prefetchImages(urls: [URL]) {
        for url in urls {
            // Skip if already cached
            if getFromMemoryCache(url: url) != nil || getFromDiskCache(url: url) != nil {
                continue
            }
            
            // Download with low priority
            _ = downloadImage(from: url, priority: .low) { _ in }
        }
    }
    
    /// Clear all caches
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    /// Clear memory cache only
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    /// Get cache size
    func getCacheSize() -> (memory: Int, disk: Int) {
        let diskSize = calculateDiskCacheSize()
        return (memory: 0, disk: diskSize) // Memory size not easily calculable
    }
    
    // MARK: - Private Methods
    
    private func downloadImage(
        from url: URL,
        priority: ImageLoadPriority,
        completion: @escaping (Result<UIImage, ImageCacheError>) -> Void
    ) -> ImageLoadTask {
        lock.lock()
        
        // Check if already downloading
        if let existingOperation = activeDownloads[url] {
            existingOperation.addCompletion(completion)
            lock.unlock()
            return ImageLoadTask(url: url) { [weak self] in
                self?.cancelDownload(url: url)
            }
        }
        
        // Create new download operation
        let operation = ImageDownloadOperation(url: url, priority: priority)
        operation.addCompletion(completion)
        
        operation.completionBlock = { [weak self, weak operation] in
            guard let self = self, let operation = operation else { return }
            
            self.lock.lock()
            self.activeDownloads.removeValue(forKey: url)
            self.lock.unlock()
            
            if let image = operation.downloadedImage {
                // Store in caches
                self.storeInMemoryCache(image: image, url: url)
                self.storeInDiskCache(image: image, url: url)
            }
        }
        
        activeDownloads[url] = operation
        downloadQueue.addOperation(operation)
        
        lock.unlock()
        
        return ImageLoadTask(url: url) { [weak self] in
            self?.cancelDownload(url: url)
        }
    }
    
    private func cancelDownload(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        
        if let operation = activeDownloads[url] {
            operation.cancel()
            activeDownloads.removeValue(forKey: url)
        }
    }
    
    // MARK: - Memory Cache
    
    private func getFromMemoryCache(url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        return memoryCache.object(forKey: key as NSString)
    }
    
    private func storeInMemoryCache(image: UIImage, url: URL) {
        let key = cacheKey(for: url)
        let cost = imageCost(image)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
    
    // MARK: - Disk Cache
    
    private func getFromDiskCache(url: URL) -> UIImage? {
        let fileURL = diskCacheFileURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func storeInDiskCache(image: UIImage, url: URL) {
        let fileURL = diskCacheFileURL(for: url)
        
        // Use JPEG compression for disk storage
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        try? data.write(to: fileURL, options: .atomic)
        
        // Check disk cache size and clean if needed
        if calculateDiskCacheSize() > maxDiskCacheSize {
            cleanOldestCacheFiles()
        }
    }
    
    private func diskCacheFileURL(for url: URL) -> URL {
        let filename = cacheKey(for: url)
        return diskCacheURL.appendingPathComponent(filename)
    }
    
    private func cacheKey(for url: URL) -> String {
        return url.absoluteString.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
    
    // MARK: - Cache Management
    
    private func calculateDiskCacheSize() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, fileURL in
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + fileSize
        }
    }
    
    private func cleanOldestCacheFiles() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        // Sort by modification date (oldest first)
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }
        
        var currentSize = calculateDiskCacheSize()
        let targetSize = maxDiskCacheSize / 2 // Clean to 50% of max
        
        for file in sortedFiles {
            guard currentSize > targetSize else { break }
            
            let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? fileManager.removeItem(at: file)
            currentSize -= fileSize
        }
    }
    
    private func cleanExpiredCache() {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        for file in files {
            let modificationDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            
            if modificationDate < expirationDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        clearMemoryCache()
    }
}

// MARK: - Supporting Types

enum ImageLoadPriority {
    case low
    case normal
    case high
    
    var queuePriority: Operation.QueuePriority {
        switch self {
        case .low: return .low
        case .normal: return .normal
        case .high: return .high
        }
    }
}

enum ImageCacheError: Error {
    case downloadFailed
    case invalidData
    case cancelled
    
    var message: String {
        switch self {
        case .downloadFailed: return "Не удалось загрузить изображение"
        case .invalidData: return "Неверный формат изображения"
        case .cancelled: return "Загрузка отменена"
        }
    }
}

struct ImageLoadTask {
    let url: URL
    let cancel: () -> Void
}

// MARK: - Download Operation

private class ImageDownloadOperation: Operation {
    let url: URL
    let priority: ImageLoadPriority
    private var completions: [(Result<UIImage, ImageCacheError>) -> Void] = []
    private var task: URLSessionDataTask?
    private let lock = NSLock()
    
    var downloadedImage: UIImage?
    
    init(url: URL, priority: ImageLoadPriority) {
        self.url = url
        self.priority = priority
        super.init()
        self.queuePriority = priority.queuePriority
    }
    
    func addCompletion(_ completion: @escaping (Result<UIImage, ImageCacheError>) -> Void) {
        lock.lock()
        completions.append(completion)
        lock.unlock()
    }
    
    override func main() {
        guard !isCancelled else {
            notifyCompletions(.failure(.cancelled))
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer { semaphore.signal() }
            
            guard let self = self, !self.isCancelled else {
                self?.notifyCompletions(.failure(.cancelled))
                return
            }
            
            if let error = error {
                print("Image download error: \(error)")
                self.notifyCompletions(.failure(.downloadFailed))
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                self.notifyCompletions(.failure(.invalidData))
                return
            }
            
            self.downloadedImage = image
            self.notifyCompletions(.success(image))
        }
        
        task?.resume()
        semaphore.wait()
    }
    
    override func cancel() {
        super.cancel()
        task?.cancel()
        notifyCompletions(.failure(.cancelled))
    }
    
    private func notifyCompletions(_ result: Result<UIImage, ImageCacheError>) {
        lock.lock()
        let completionsToNotify = completions
        completions.removeAll()
        lock.unlock()
        
        DispatchQueue.main.async {
            completionsToNotify.forEach { $0(result) }
        }
    }
}
```

### 2. SwiftUI Integration

**`ios/cstatiWarehouse/CoreUI/CachedAsyncImage.swift`**:

```swift
//
//  CachedAsyncImage.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import SwiftUI

/// Cached async image with placeholder and error handling
struct CachedAsyncImage<Content: View, Placeholder: View, ErrorView: View>: View {
    
    let url: URL?
    let priority: ImageLoadPriority
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let errorView: (ImageCacheError) -> ErrorView
    
    @StateObject private var loader = ImageLoader()
    
    init(
        url: URL?,
        priority: ImageLoadPriority = .normal,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder errorView: @escaping (ImageCacheError) -> ErrorView
    ) {
        self.url = url
        self.priority = priority
        self.content = content
        self.placeholder = placeholder
        self.errorView = errorView
    }
    
    var body: some View {
        Group {
            switch loader.state {
            case .idle, .loading:
                placeholder()
                    .onAppear {
                        if let url = url {
                            loader.load(url: url, priority: priority)
                        }
                    }
                
            case .loaded(let image):
                content(Image(uiImage: image))
                
            case .failed(let error):
                errorView(error)
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

// Convenience initializers
extension CachedAsyncImage where Placeholder == Color, ErrorView == Color {
    init(
        url: URL?,
        priority: ImageLoadPriority = .normal,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            priority: priority,
            content: content,
            placeholder: { Color.gray.opacity(0.2) },
            errorView: { _ in Color.red.opacity(0.2) }
        )
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Color, ErrorView == Color {
    init(url: URL?, priority: ImageLoadPriority = .normal) {
        self.init(
            url: url,
            priority: priority,
            content: { $0.resizable() },
            placeholder: { Color.gray.opacity(0.2) },
            errorView: { _ in Color.red.opacity(0.2) }
        )
    }
}

// MARK: - Image Loader

@MainActor
final class ImageLoader: ObservableObject {
    
    enum LoadState {
        case idle
        case loading
        case loaded(UIImage)
        case failed(ImageCacheError)
    }
    
    @Published private(set) var state: LoadState = .idle
    
    private var currentTask: ImageLoadTask?
    private let cache = ImageCacheService.shared
    
    func load(url: URL, priority: ImageLoadPriority) {
        guard case .idle = state else { return }
        
        state = .loading
        
        currentTask = cache.loadImage(from: url, priority: priority) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let image):
                    self.state = .loaded(image)
                case .failure(let error):
                    self.state = .failed(error)
                }
            }
        }
    }
    
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
```

### 3. Usage Examples

**Simple Usage**:
```swift
CachedAsyncImage(url: item.photoURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

**With Custom Placeholder**:
```swift
CachedAsyncImage(
    url: item.photoURL,
    priority: .high
) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    ZStack {
        Color.gray.opacity(0.2)
        ProgressView()
    }
} errorView: { error in
    ZStack {
        Color.red.opacity(0.1)
        Image(systemName: "photo.fill")
            .foregroundColor(.gray)
    }
}
.frame(width: 100, height: 100)
.clipShape(RoundedRectangle(cornerRadius: 12))
```

**In List with Prefetching**:
```swift
List {
    ForEach(items) { item in
        HStack {
            CachedAsyncImage(url: item.photoURL, priority: .high) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading) {
                Text(item.name)
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            // Prefetch next items
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                let nextItems = items.dropFirst(index + 1).prefix(5)
                let urls = nextItems.compactMap { $0.photoURL }
                ImageCacheService.shared.prefetchImages(urls: urls)
            }
        }
    }
}
```

### 4. Settings Integration

**Cache Management View**:
```swift
struct CacheManagementView: View {
    @State private var cacheSize: (memory: Int, disk: Int) = (0, 0)
    @State private var showClearConfirmation = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Размер кэша на диске")
                    Spacer()
                    Text(formatBytes(cacheSize.disk))
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button("Очистить кэш изображений") {
                    showClearConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Кэш изображений")
        .onAppear {
            updateCacheSize()
        }
        .alert("Очистить кэш?", isPresented: $showClearConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Очистить", role: .destructive) {
                ImageCacheService.shared.clearCache()
                updateCacheSize()
            }
        } message: {
            Text("Все изображения будут загружены заново при следующем просмотре")
        }
    }
    
    private func updateCacheSize() {
        cacheSize = ImageCacheService.shared.getCacheSize()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
```

## Performance Optimization

### 1. Image Downsampling

For large images, downsample before displaying:

```swift
extension UIImage {
    func downsample(to targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let data = self.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * UIScreen.main.scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}
```

### 2. Thumbnail Generation

Generate thumbnails on backend (Lambda@Edge) or iOS:

```swift
// Request thumbnail from CDN
let thumbnailURL = url.appendingPathComponent("?w=200&h=200&f=webp")
```

### 3. Progressive Loading

Load low-quality placeholder first, then high-quality:

```swift
struct ProgressiveImage: View {
    let url: URL?
    
    var body: some View {
        ZStack {
            // Low quality (thumbnail)
            if let thumbnailURL = url?.appendingPathComponent("?w=50&q=30") {
                CachedAsyncImage(url: thumbnailURL, priority: .high) { image in
                    image
                        .resizable()
                        .blur(radius: 2)
                }
            }
            
            // High quality
            CachedAsyncImage(url: url, priority: .normal) { image in
                image.resizable()
            }
        }
    }
}
```

## Memory Management

### 1. Automatic Cleanup

```swift
// In ImageCacheService
private func setupMemoryPressureHandling() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleMemoryWarning),
        name: UIApplication.didReceiveMemoryWarningNotification,
        object: nil
    )
}

@objc private func handleMemoryWarning() {
    clearMemoryCache()
    
    // Cancel low-priority downloads
    lock.lock()
    for (url, operation) in activeDownloads where operation.priority == .low {
        operation.cancel()
        activeDownloads.removeValue(forKey: url)
    }
    lock.unlock()
}
```

### 2. Background Task Cleanup

```swift
// In AppDelegate
func applicationDidEnterBackground(_ application: UIApplication) {
    ImageCacheService.shared.clearMemoryCache()
}
```

## Testing

### Unit Tests

```swift
final class ImageCacheServiceTests: XCTestCase {
    var sut: ImageCacheService!
    
    override func setUp() {
        super.setUp()
        sut = ImageCacheService.shared
        sut.clearCache()
    }
    
    func testMemoryCaching() {
        let url = URL(string: "https://example.com/image.jpg")!
        let image = UIImage(systemName: "photo")!
        
        // Store in cache
        sut.storeInMemoryCache(image: image, url: url)
        
        // Retrieve from cache
        let cachedImage = sut.getFromMemoryCache(url: url)
        XCTAssertNotNil(cachedImage)
    }
    
    func testDiskCaching() async {
        let url = URL(string: "https://example.com/image.jpg")!
        let image = UIImage(systemName: "photo")!
        
        // Store in disk cache
        sut.storeInDiskCache(image: image, url: url)
        
        // Retrieve from disk cache
        let cachedImage = sut.getFromDiskCache(url: url)
        XCTAssertNotNil(cachedImage)
    }
    
    func testCacheSizeLimit() {
        // Test that cache respects size limits
        // Add many large images
        // Verify oldest are removed
    }
}
```

## Best Practices

1. **Always use CachedAsyncImage** instead of AsyncImage
2. **Set appropriate priorities** (high for visible, low for prefetch)
3. **Prefetch next items** in lists for smooth scrolling
4. **Cancel downloads** when views disappear
5. **Use thumbnails** for list views, full size for detail views
6. **Monitor cache size** and provide clear option in settings
7. **Handle memory warnings** by clearing memory cache
8. **Use progressive loading** for large images
9. **Downsample large images** before displaying
10. **Test on real devices** with limited memory

## Monitoring

### Analytics Events

```swift
// Track cache performance
Analytics.logEvent("image_cache_hit", parameters: ["url": url])
Analytics.logEvent("image_cache_miss", parameters: ["url": url])
Analytics.logEvent("image_download_failed", parameters: ["url": url, "error": error])
```

### Performance Metrics

- Cache hit rate (target: > 80%)
- Average load time (target: < 500ms)
- Memory usage (target: < 100MB)
- Disk cache size (target: < 500MB)

## References

- [Apple: Loading and Displaying Images](https://developer.apple.com/documentation/uikit/images_and_pdf/loading_and_displaying_images)
- [WWDC: Image and Graphics Best Practices](https://developer.apple.com/videos/play/wwdc2018/219/)
- [NSCache Documentation](https://developer.apple.com/documentation/foundation/nscache)
- [URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
