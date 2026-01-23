import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("MotrixMac")
                    .font(.system(size: 24, weight: .bold))

                Text(
                    "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Text("A full-featured download manager")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Link(
                    "GitHub Repository",
                    destination: URL(string: "https://github.com/shawnrain/MotrixMac")!
                )
                .font(.body)
            }
            .padding(.top, 10)

            Spacer()

            Text("Copyright © 2024 Shawn Rain. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AboutView()
}
