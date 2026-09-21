import AppKit

/// 平台图标：内置官方图标的加载、简约模式用的单色剪影着色
enum PlatformIcon {
    /// 生成图标的单色剪影（简约模式菜单栏着色用）：颜色为目标色，形状取原图字形、保留抗锯齿边缘
    ///
    /// 蒙版按图标结构自动选择：
    /// - 透明底图形 / 整体单色图形（如 DeepSeek 鲸鱼）：以 alpha 作蒙版；
    /// - 不透明底板 + 内嵌亮/暗字形（如智谱深灰底白 Z）：以不透明像素亮度中位数为底板亮度，
    ///   |亮度 − 底板| 按 95 分位归一化作蒙版，剥离底板只留字形（亮字 / 暗字两个方向均适用）
    static func tintedSilhouette(of image: NSImage, color: NSColor) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let width = cgImage.width, height = cgImage.height
        let pixelCount = width * height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard pixelCount > 0,
              let srcContext = CGContext(
                  data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return image }
        srcContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let src = srcContext.data?.assumingMemoryBound(to: UInt8.self),
              let dstContext = CGContext(
                  data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let dst = dstContext.data?.assumingMemoryBound(to: UInt8.self)
        else { return image }

        /// 该像素直通（非预乘）RGB 的亮度
        func luminance(_ i: Int) -> Double {
            let a = Double(src[i + 3]) / 255
            guard a > 0 else { return 0 }
            return (0.299 * Double(src[i]) + 0.587 * Double(src[i + 1]) + 0.114 * Double(src[i + 2])) / 255 / a
        }

        // 结构判定：主要不透明像素亮度离散度高、且透明占比低 → 不透明底板 + 内嵌字形
        var lums: [Double] = []
        var transparent = 0
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            if Double(src[i + 3]) >= 128 {
                lums.append(luminance(i))
            } else {
                transparent += 1
            }
        }
        var plateKeying = false
        var plateLum = 0.0
        var distanceScale = 1.0
        if lums.count > 10 {
            let sorted = lums.sorted()
            let mean = sorted.reduce(0, +) / Double(sorted.count)
            let std = (sorted.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(sorted.count)).squareRoot()
            if std > 0.08, Double(transparent) / Double(pixelCount) < 0.25 {
                plateKeying = true
                plateLum = sorted[sorted.count / 2]
                let distances = sorted.map { abs($0 - plateLum) }.sorted()
                distanceScale = max(distances[Int(0.95 * Double(distances.count - 1))], 0.02)
            }
        }

        // 底板边缘常带一圈与字形同亮度的描边/白边（如智谱图标的方形 rim）：
        // 多源 BFS 距离变换，把 alpha 边界数像素内的蒙版清零，剥离贴边描边、只留内部字形
        var boundaryDist = [Int](repeating: -1, count: pixelCount)
        if plateKeying {
            func isOpaque(_ idx: Int) -> Bool { Double(src[idx * 4 + 3]) >= 128 }
            let peelPixels = max(2, min(width, height) / 32)
            var queue: [Int] = []
            queue.reserveCapacity(pixelCount)
            for idx in 0..<pixelCount where isOpaque(idx) {
                let x = idx % width, y = idx / width
                let atEdge = x == 0 || y == 0 || x == width - 1 || y == height - 1
                let touchesHole = (x > 0 && !isOpaque(idx - 1)) || (x < width - 1 && !isOpaque(idx + 1))
                    || (y > 0 && !isOpaque(idx - width)) || (y < height - 1 && !isOpaque(idx + width))
                if atEdge || touchesHole {
                    boundaryDist[idx] = 0
                    queue.append(idx)
                }
            }
            var head = 0
            while head < queue.count {
                let idx = queue[head]
                head += 1
                guard boundaryDist[idx] < peelPixels else { continue }
                let x = idx % width, y = idx / width
                for neighbor in [x > 0 ? idx - 1 : -1, x < width - 1 ? idx + 1 : -1,
                                 y > 0 ? idx - width : -1, y < height - 1 ? idx + width : -1] {
                    if neighbor >= 0, boundaryDist[neighbor] == -1, isOpaque(neighbor) {
                        boundaryDist[neighbor] = boundaryDist[idx] + 1
                        queue.append(neighbor)
                    }
                }
            }
        }

        let tint = color.usingColorSpace(.deviceRGB) ?? NSColor.gray
        let tr = tint.redComponent, tg = tint.greenComponent, tb = tint.blueComponent
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            let alpha = Double(src[i + 3]) / 255
            // boundaryDist == -1 表示距 alpha 边界超过剥离宽度（未被 BFS 触达）
            let mask: Double
            if plateKeying {
                mask = boundaryDist[i / 4] == -1
                    ? alpha * min(abs(luminance(i) - plateLum) / distanceScale, 1)
                    : 0
            } else {
                mask = alpha
            }
            dst[i] = UInt8(tr * mask * 255)
            dst[i + 1] = UInt8(tg * mask * 255)
            dst[i + 2] = UInt8(tb * mask * 255)
            dst[i + 3] = UInt8(mask * 255)
        }

        guard let silhouette = dstContext.makeImage() else { return image }
        let result = NSImage(size: image.size)
        let rep = NSBitmapImageRep(cgImage: silhouette)
        rep.size = image.size
        result.addRepresentation(rep)
        return result
    }

    /// 内置官方图标（随包分发的 PNG，见 Assets/platform-icons 与 build-app.sh）
    static func defaultIcon(for platform: Platform) -> NSImage? {
        for url in defaultIconURLs(named: resourceName(for: platform)) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private static func resourceName(for platform: Platform) -> String {
        switch platform {
        case .zhipu: return "zhipu-icon"
        case .deepseek: return "deepseek-icon"
        }
    }

    /// 内置图标的候选位置：.app 的 Contents/Resources、可执行文件所在目录
    private static func defaultIconURLs(named name: String) -> [URL] {
        [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { base in
            base?.appendingPathComponent("\(name).png")
        }
    }
}
