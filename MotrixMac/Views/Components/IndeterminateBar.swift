import SwiftUI

/// A custom indeterminate progress bar with a gradient animation.
struct IndeterminateBar: View {
    @State private var offset: CGFloat = -1.0
    var tint: Color = .accentColor
    var height: CGFloat = 6
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                
                // Moving pill
                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, tint.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: offset * geometry.size.width)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    offset = 2.0
                }
            }
        }
        .frame(height: height)
    }
}
