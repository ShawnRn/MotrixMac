import SwiftUI

/// A view that renders the download pieces/bitfield in an IDM-like style but adapted for macOS.
struct PieceProgressView: View {
    let bitfield: String
    let numPieces: Int
    let connections: Int
    
    // Convert hex bitfield to a boolean array
    private var pieces: [Bool] {
        var result = [Bool]()
        for char in bitfield {
            if let value = Int(String(char), radix: 16) {
                for i in (0..<4).reversed() {
                    result.append((value >> i) & 1 == 1)
                }
            }
        }
        // Trim to numPieces if needed, aria2 might pad to 4-bit boundaries
        if result.count > numPieces && numPieces > 0 {
            return Array(result.prefix(numPieces))
        }
        return result
    }
    
    // Aggregate pieces into a fixed number of display segments for better visibility
    private var displaySegments: [Double] {
        let pieceList = pieces
        guard !pieceList.isEmpty else { return [] }
        
        let maxSegments = 60 // Fewer segments = wider, chunkier blocks
        let segmentCount = min(pieceList.count, maxSegments)
        var result = [Double]()
        
        for i in 0..<segmentCount {
            let start = i * pieceList.count / segmentCount
            let end = (i + 1) * pieceList.count / segmentCount
            let subrange = pieceList[start..<end]
            let completed = subrange.filter { $0 }.count
            let total = subrange.count
            result.append(Double(completed) / Double(max(1, total)))
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("分块进度")
                    .font(.subheadline.weight(.medium))
                
                if connections > 0 {
                    Text("\(connections) 线程")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
                Text("\(numPieces) 分块")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geometry in
                let segments = displaySegments
                Canvas { context, size in
                    let pieceWidth = size.width / CGFloat(max(1, segments.count))
                    
                    for (index, progress) in segments.enumerated() {
                        let xOffset = CGFloat(index) * pieceWidth
                        let rect = CGRect(x: xOffset, y: 0, width: pieceWidth + 0.5, height: size.height)
                        
                        // Background (Unfinished)
                        context.fill(Path(rect), 
                                   with: .color(Color.primary.opacity(0.08)))
                        
                        if progress > 0 {
                            // Foreground (Finished or Partial)
                            let color = progress == 1.0 ? Color.green : Color.accentColor
                            let opacity = progress == 1.0 ? 1.0 : 0.6
                            
                            context.fill(Path(rect), 
                                       with: .color(color.opacity(opacity)))
                        }
                    }
                }
            }
            .frame(height: 14)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PieceProgressView(bitfield: "f0f0f0f0f0f0", numPieces: 48, connections: 8)
            .frame(width: 400)
        
        PieceProgressView(bitfield: "ffffffff0000", numPieces: 48, connections: 16)
            .frame(width: 400)
    }
    .padding()
}
