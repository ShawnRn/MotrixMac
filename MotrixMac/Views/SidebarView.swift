import Observation
import SwiftUI

/// Sidebar navigation with Liquid Glass styling
struct SidebarView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Binding var selectedCategory: TaskCategory

    var body: some View {
        VStack(spacing: 0) {
            // App logo area with drag region
            LogoHeader()
                .padding(.top, 48)
                .padding(.bottom, 24)

            // Navigation items - task categories
            VStack(spacing: 8) {
                ForEach(TaskCategory.taskCategories) { category in
                    SidebarItem(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: downloadManager.taskCount(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Bottom actions
            VStack(spacing: 8) {
                // Settings - navigate to settings in main content
                SidebarItem(
                    category: .settings,
                    isSelected: selectedCategory == .settings,
                    count: 0
                ) {
                    selectedCategory = .settings
                }

                // About - navigate to about in main content
                SidebarItem(
                    category: .about,
                    isSelected: selectedCategory == .about,
                    count: 0
                ) {
                    selectedCategory = .about
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Subtle gradient for sidebar depth
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.02),
                    Color.clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        // Note: .glassEffect(.sidebar) will be available in macOS 26 SDK
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.container, edges: .top)
    }
}

// MARK: - Logo Header

struct LogoHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("SidebarIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            Text("MotrixMac")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let category: TaskCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(category.title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.2) : .secondary.opacity(0.15))
                        }
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
            }
            .contentShape(Rectangle()) // Hit test entire strip
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar Action Button

struct SidebarActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)

                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Task Category

// Moved to AppModels.swift

#Preview {
    SidebarView(selectedCategory: .constant(.downloading))
        .environment(DownloadManager.shared)
        .frame(width: 200, height: 600)
}
