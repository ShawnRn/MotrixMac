import SwiftUI
import Sparkle


struct AboutView: View {
    @AppStorage("language") private var language = "zh-CN"
    @State private var licenses: [LicenseItem] = [
        LicenseItem(
            name: "Motrix",
            license: "MIT",
            description: "A full-featured download manager.\nhttps://github.com/agalwood/Motrix\nCopyright (c) 2018-present Dr_rOot",
            type: "Inspiration"
        ),
        LicenseItem(
            name: "aria2",
            license: "GPL-2.0",
            description: "Lightweight multi-protocol & multi-source command-line download utility.\nhttps://aria2.github.io/",
            type: "Core"
        ),
        LicenseItem(
            name: "Sparkle",
            license: "MIT",
            description: "A software update framework for macOS.\nhttps://sparkle-project.org/\nOriginal creator Andy Matuschak, maintained by the Sparkle Project.",
            type: "Framework"
        ),
        LicenseItem(
            name: "Motrix WebExtension",
            license: "GPL-3.0",
            description: "Browser extension for capturing downloads.\nhttps://github.com/gautamkrishnar/motrix-webextension",
            type: "Tooling"
        ),
        LicenseItem(
            name: "Antigravity",
            license: "AI Native",
            description: "Developed with ❤️ using Antigravity, the powerful AI coding assistant by Google DeepMind.\nhttps://antigravity.google/",
            type: "Credits"
        )
    ]
    @State private var changelogs: [ChangelogItem] = [
        ChangelogItem(
            version: "1.2.5",
            date: "2026-06-08",
            changes: [
                "修复了后台挂载较久、网络切换或电脑休眠后，浏览器插件发送下载任务可能不显示系统通知的问题。",
                "优化了启动长连接初始化流程，使得在无主窗口的静默后台运行状态下也能正常接收下载事件。",
                "优化了底层网络恢复时的自适应后台重连机制，避免误判引擎崩溃并提升连接稳定性。"
            ]
        ),
        ChangelogItem(
            version: "1.2.4",
            date: "2026-05-18",
            changes: [
                "修复了长时间使用后新增下载任务可能不显示的问题。",
                "修复了空白搜索条件导致列表只显示部分已完成任务的问题。",
                "优化了 aria2 日志级别与日志轮转，降低长时间运行后的卡顿风险。",
                "优化了新增任务后的会话保存机制，提升重启后的任务恢复稳定性。"
            ]
        ),
        ChangelogItem(
            version: "1.2.2",
            date: "2026-02-24",
            changes: [
                "优化了下载失败回退机制，修复了部分任务下载失败的问题。",
                "修复了一些已知问题，提升了稳定性。"
            ]
        ),
        ChangelogItem(
            version: "1.2.1",
            date: "2026-02-23",
            changes: [
                "新增 Dock 图标下载速度指示器和进度条。",
                "新增下载完成角标计数。",
                "修复了一些 bugs。"
            ]
        ),
        ChangelogItem(
            version: "1.2",
            date: "2026-02-21",
            changes: [
                "优化了下载尾段掉速问题。",
                "修复了在勾选「同时删除本地文件」时文件实际并未删除的问题。",
                "优化了重复添加任务时的重命名机制。"
            ]
        ),
        ChangelogItem(
            version: "1.1.9",
            date: "2026-02-17",
            changes: [
                "更新了图标。",
                "进一步完善了多语言本地化。",
                "优化了 UI 细节。"
            ]
        ),
        ChangelogItem(
            version: "1.1.8",
            date: "2026-02-16",
            changes: [
                "新增定期自动清除任务功能。",
                "优化了多语言支持，现在支持中英日韩。",
                "修复了一些界面 bugs。"
            ]
        ),
        ChangelogItem(
            version: "1.1.7",
            date: "2026-02-13",
            changes: [
                "修复了下载完成不弹出通知的 bug。",
                "小幅优化界面细节。",
                "重构了删除确认弹窗的数据传递机制，提升稳定性。"
            ]
        ),
        ChangelogItem(
            version: "1.1.6",
            date: "2026-02-13",
            changes: [
                "新增「单列表模式」：合并下载中和已完成任务，专注当前任务。",
                "优化了设置界面，新增功能说明。",
                "修复了 BT 下载的 bugs。"
            ]
        ),
        ChangelogItem(
            version: "1.1.5",
            date: "2026-02-06",
            changes: [
                "完善了 BitTorrent 下载功能。",
                "优化了界面细节。",
                "修复了一些 bugs。",
                "如果你发现了 bug，请提交 issue 或发邮件给我😃！"
            ]
        ),
        ChangelogItem(
            version: "1.1.4",
            date: "2026-02-02",
            changes: [
                "新增切换 Tabs 时的动画。",
                "新增支持通过 Esc 键快速关闭任务详情侧边栏。",
                "重构「开源许可」与「更新日志」弹窗。",
                "微调了删除任务的弹窗。",
                "修复了一些 bugs。"
            ]
        ),
        ChangelogItem(
            version: "1.1.3",
            date: "2026-02-02",
            changes: [
                "小幅优化界面。"
            ]
        ),
        ChangelogItem(
            version: "1.1.2",
            date: "2026-02-01",
            changes: [
                "优化了速度曲线的采样逻辑。",
                "详细信息新增「峰值速度」勋章徽标。",
                "优化了图标。"
            ]
        ),
        ChangelogItem(
            version: "1.1.1",
            date: "2026-02-01",
            changes: [
                "新增 .icns 文件缩略图支持及 Quick Look 预览。",
                "优化了双击打开文件的动画效果（仿 Finder 放大）。",
                "修复了一些 bugs。"
            ]
        ),
        ChangelogItem(
            version: "1.1",
            date: "2026-01-30",
            changes: [
                "优化了任务列表排序逻辑：已完成任务按时间倒序排列，移除文件的任务自动沉底。",
                "修复了 Quick Look 预览动画的若干问题，现在更加丝滑流畅。",
                "修复了任务列表状态文字丢失的问题。",
                "优化了 UI 细节，文件缺失的任务显示为灰色。"
            ]
        ),
        ChangelogItem(
            version: "1.0.9",
            date: "2026-01-27",
            changes: [
                "修复了日志级别无法选择的问题。"
            ]
        ),
        ChangelogItem(
            version: "1.0.8",
            date: "2026-01-27",
            changes: [
                "支持 Quick Look 方向键切换预览。",
                "详细信息侧边栏新增图片文件缩略图。",
                "修复了点击 Dock 图标意外重置回主页的问题。",
                "修复了一些 bugs，提升了稳定性。"
            ]
        ),
        ChangelogItem(
            version: "1.0.7",
            date: "2026-01-27",
            changes: [
                "新增图片缩略图预览功能。",
                "集成原生 Quick Look 支持，现在可以在「已完成」列表中空格预览。"
            ]
        ),
        ChangelogItem(
            version: "1.0.6",
            date: "2026-01-27",
            changes: [
                "新增了自动更新功能。",
                "补全了部分界面的本地化。"
            ]
        ),
        ChangelogItem(
            version: "1.0.5",
            date: "2026-01-26",
            changes: [
                "修改了部分界面文本表述。",
                "修改了部分界面样式，速度指示器移到右上角。",
                "修复了一些 bug，优化了性能。"
            ]
        ),
        ChangelogItem(
            version: "1.0.4",
            date: "2026-01-24",
            changes: [
                "修复了打开 App 默认不会回到主页的问题。",
                "修复了 URL Scheme 不起作用的问题。",
                "修复了双击 Dock 图标会打开多个窗口的问题。"
            ]
        ),
        ChangelogItem(
            version: "1.0.3",
            date: "2026-01-24",
            changes: [
                "首个 Release 版本。"
            ]
        ),
        ChangelogItem(
            version: "1.0.2",
            date: "2026-01-23",
            changes: [
                "实现了稳健的引擎自愈系统。",
                "修复了侧边栏双击打开的显示问题。",
                "优化任务列表滚动性能。",
                "任务列表支持多选操作。"
            ]
        ),
        ChangelogItem(
            version: "1.0.1",
            date: "2026-01-20",
            changes: [
                "MotrixMac 初始版本发布。",
                "支持 HTTP, 基础 FTP 以及 BitTorrent 下载。",
                "集成浏览器扩展支持。"
            ]
        )
    ]
    @State private var showLicenses = false
    @State private var showChangelog = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 30) {
                // App Info
                VStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                        .background {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)
                        }
                        
                    VStack(spacing: 6) {
                        Text("MotrixMac")
                            .font(.system(size: 24, weight: .semibold))
                            
                        Text(String(format: "版本 %1$@ (%2$@)".localized(for: language), 
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.2",
                            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2026022418"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            
                        Text("一个轻量化的、全原生 Swift 实现的下载工具。".localized(for: language))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                // Navigation Links
                HStack(spacing: 24) {
                    AboutButton(icon: "doc.text.fill", title: "开源许可".localized(for: language)) {
                        showLicenses = true
                    }
                    .sheet(isPresented: $showLicenses) {
                        LicenseView(licenses: licenses)
                            .frame(width: 600, height: 500)
                    }
                    
                    AboutButton(icon: "globe", title: "GitHub", isLink: true, url: "https://github.com/ShawnRn/MotrixMac")

                    AboutButton(icon: "clock.arrow.circlepath", title: "更新日志".localized(for: language)) {
                        showChangelog = true
                    }
                    .sheet(isPresented: $showChangelog) {
                        ChangelogView(changelogs: changelogs)
                            .frame(width: 600, height: 500)
                    }

                }
            }
            
            Spacer()
            
            // Update Button at bottom
            Button {
                AppDelegate.shared?.updaterController.checkForUpdates(nil)
            } label: {
                Label("检查更新".localized(for: language), systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(SidebarButtonStyle())
            .padding(.bottom, 20)
            
            // Footer
            VStack(spacing: 6) {
                Text("Made with ❤️ by Shawn Rain".localized(for: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    let mailto = "mailto:shawnrain.me@gmail.com"
                    if let url = URL(string: mailto) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("shawnrain.me@gmail.com")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                .padding(.bottom, 2)
                
                Text("MIT Copyright (c) 2026-present Shawn Rain".localized(for: language))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AboutView()
}

// MARK: - About Button Component

struct AboutButton: View {
    let icon: String
    let title: String
    var isLink: Bool = false
    var url: String = ""
    var action: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        Group {
            if isLink, let destination = URL(string: url) {
                Link(destination: destination) {
                    buttonContent
                }
            } else {
                Button {
                    action?()
                } label: {
                    buttonContent
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var buttonContent: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.accentColor.opacity(0.12) : .secondary.opacity(0.08))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        isHovered ? .white.opacity(colorScheme == .dark ? 0.4 : 0.8) : .white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                                        .clear,
                                        isHovered ? .white.opacity(colorScheme == .dark ? 0.1 : 0.2) : .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: isHovered ? Color.accentColor.opacity(0.2) : .black.opacity(0.05), 
                            radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(isHovered ? .primary : .secondary)
        }
        .frame(width: 80)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}
