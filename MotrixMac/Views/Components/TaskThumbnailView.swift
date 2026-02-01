import SwiftUI
import AppKit

struct TaskThumbnailView: View {
    let task: DownloadTask
    let size: CGFloat
    let initialImage: NSImage?
    var onImageLoaded: (NSImage) -> Void = { _ in }
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = false
    
    init(task: DownloadTask, size: CGFloat, initialImage: NSImage? = nil, onImageLoaded: @escaping (NSImage) -> Void = { _ in }) {
        self.task = task
        self.size = size
        self.initialImage = initialImage
        self.onImageLoaded = onImageLoaded
        _thumbnail = State(initialValue: initialImage)
    }
    
    var body: some View {
        ZStack {
            // 背景占位图标：始终存在以维持布局稳定
            FileIconView(fileType: .image)
                .frame(width: size, height: size)
                .opacity(thumbnail == nil ? 1.0 : 0.0)
            
            // 缩略图：加载后覆盖显示
            if let thumbnail {
                if task.name.lowercased().hasSuffix(".icns") {
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(6)
                    }
                    .frame(width: size, height: size)
                } else {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            generateThumbnail()
        }
        .onChange(of: task.id) { _, _ in
            self.thumbnail = nil // 立即清除旧图，防止残留
            generateThumbnail()
        }
        .onChange(of: task.status) { _, newStatus in
            if newStatus == "complete" {
                generateThumbnail()
            }
        }
    }
    
    private func generateThumbnail() {
        // 如果已经有图了（通过 init 注入），且不是为了更新，则跳过
        if thumbnail != nil && !isLoading {
             return
        }

        // 放宽限制：只要有有效文件路径且未在加载中，即尝试生成（即使任务未显示为 complete，文件可能已存在）
        guard !isLoading else { return }
        
        // Use the first file path if available
        
        // Use the first file path if available
        guard let filePath = task.files.first?.path, !filePath.isEmpty else { return }
        let url = URL(fileURLWithPath: filePath)
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
                DispatchQueue.main.async { isLoading = false }
                return
            }
            
            let maxDimensionInPixels = size * 2 // Retina support
            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
            ] as CFDictionary
            
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions) {
                let nsImage = NSImage(cgImage: cgImage, size: .zero)
                DispatchQueue.main.async {
                    self.thumbnail = nsImage
                    self.isLoading = false
                    self.onImageLoaded(nsImage)
                }
            } else {
                DispatchQueue.main.async { isLoading = false }
            }
        }
    }
}
