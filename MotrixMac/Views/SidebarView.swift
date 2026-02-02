import Observation
import SwiftUI

/// Sidebar navigation with Liquid Glass styling
struct SidebarView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Binding var selectedCategory: TaskCategory
    @State private var hoveredCategory: TaskCategory? = nil

    @Namespace private var sidebarNamespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // App logo area with drag region
            LogoHeader()
                .padding(.top, 56)
                .padding(.bottom, 32)

            // Navigation items - task categories
            VStack(spacing: 8) {
                ForEach(TaskCategory.taskCategories) { category in
                    SidebarItem(
                        category: category,
                        isSelected: selectedCategory == category,
                        isHovered: hoveredCategory == category,
                        count: downloadManager.taskCount(for: category),
                        namespace: sidebarNamespace
                    ) {
                        if selectedCategory != category {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedCategory = category
                            }
                        }
                    }
                    .onHover { isHovered in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoveredCategory = isHovered ? category : nil
                        }
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
                    isHovered: hoveredCategory == .settings,
                    count: 0,
                    namespace: sidebarNamespace
                ) {
                    if selectedCategory != .settings {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedCategory = .settings
                        }
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredCategory = isHovered ? .settings : nil
                    }
                }

                // About - navigate to about in main content
                SidebarItem(
                    category: .about,
                    isSelected: selectedCategory == .about,
                    isHovered: hoveredCategory == .about,
                    count: 0,
                    namespace: sidebarNamespace
                ) {
                    if selectedCategory != .about {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedCategory = .about
                        }
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredCategory = isHovered ? .about : nil
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
    }
}

// Preference Keys for Layout Source (Simplified approach using matchedGeometryEffect directly is preferred)
// But to be even more robust, we can just use the Namespace pattern.

// MARK: - Logo Header

struct LogoHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("MotrixMac")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    let category: TaskCategory
    let isSelected: Bool
    let isHovered: Bool
    let count: Int
    let namespace: Namespace.ID
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
                ZStack {
                    if isHovered && !isSelected {
                        Capsule()
                            .fill(.secondary.opacity(0.08))
                            .transition(.opacity)
                    }
                    
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(
                                id: (category == .downloading || category == .completed) ? "selection_top" : "selection_bottom",
                                in: namespace
                            )
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                            .overlay {
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(colorScheme == .dark ? 0.25 : 0.5), 
                                                .clear, 
                                                .white.opacity(colorScheme == .dark ? 0.1 : 0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                    }
                }
            }
        }
        .buttonStyle(SidebarButtonStyle())
    }
}

// MARK: - Button Style

struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
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
