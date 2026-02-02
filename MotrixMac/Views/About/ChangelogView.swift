import SwiftUI

struct ChangelogView: View {
    let changelogs: [ChangelogItem]
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
                VStack(spacing: 20) {
                    ForEach(changelogs) { item in
                        versionCard(for: item)
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
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("更新日志")
                    .font(.system(size: 22, weight: .bold))
                Text("记录 MotrixMac 进化的点点滴滴。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
    
    @ViewBuilder
    private func versionCard(for item: ChangelogItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("v\(item.version)")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text(item.date)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            
            Divider()
                .opacity(colorScheme == .dark ? 0.1 : 0.05)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(item.changes, id: \.self) { change in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                        
                        Text(change)
                            .font(.system(size: 13))
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? .white.opacity(0.04) : .white.opacity(0.4))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.03), radius: 10, x: 0, y: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.12 : 0.25),
                            .clear,
                            .white.opacity(colorScheme == .dark ? 0.03 : 0.06)
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
