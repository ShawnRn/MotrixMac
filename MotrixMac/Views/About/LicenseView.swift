import SwiftUI

struct LicenseView: View {
    let licenses: [LicenseItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            headerView
            
            Divider()
                .opacity(colorScheme == .dark ? 0.1 : 0.05)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(licenses) { item in
                        licenseCard(for: item)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.never)
            
            Divider()
                .opacity(colorScheme == .dark ? 0.1 : 0.05)
            
            footerView
        }
        .background(.ultraThinMaterial)
    }
    
    private var headerView: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("开源许可")
                    .font(.system(size: 22, weight: .bold))
                Text("感谢这些伟大的开源项目，它们让 MotrixMac 的诞生成为可能。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
    
    @ViewBuilder
    private func licenseCard(for item: LicenseItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.name)
                    .font(.headline)
                
                Text(item.license)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.accentColor)
                
                Spacer()
                
                Text(item.type)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Text(item.description)
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? .white.opacity(0.03) : .white.opacity(0.3))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.02), radius: 8, x: 0, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                            .clear,
                            .white.opacity(colorScheme == .dark ? 0.02 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    private var footerView: some View {
        HStack {
            Spacer()
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
