import SwiftUI
import Sparkle


struct AboutView: View {
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
            version: "1.1.1",
            date: "2026-02-01",
            changes: [
                "优化了侧边栏动画，恢复了丝滑的从右侧滑入效果。",
                "修复了详细信息侧边栏位置偏移的问题。",
                "新增 .icns 文件缩略图支持及 Quick Look 预览。",
                "优化了双击打开文件的动画效果（仿 Finder 放大）。",
                "修复了 Quick Look 预览窗口关闭时的闪烁问题。"
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
                        .frame(width: 110, height: 110)
                        
                    VStack(spacing: 6) {
                        Text("MotrixMac")
                            .font(.system(size: 24, weight: .semibold))
                            
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            
                        Text("一个轻量化的、全原生 Swift 实现的下载工具。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                // Navigation Links
                HStack(spacing: 40) {
                    Button {
                        showLicenses = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                            Text("开源许可")
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showLicenses) {
                        LicenseView(licenses: licenses)
                            .frame(width: 600, height: 500)
                    }
                    
                    Link(destination: URL(string: "https://github.com/ShawnRn/MotrixMac")!) {
                        VStack(spacing: 6) {
                            Image(systemName: "globe")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .symbolRenderingMode(.hierarchical)
                            Text("GitHub")
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showChangelog = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 24))
                            Text("更新日志")
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)
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
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("检查更新")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
            
            // Footer
            VStack(spacing: 6) {
                Text("Made with ❤️ by Shawn Rain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Copyright © 2026 Shawn Rain. All rights reserved.")
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
