import SwiftUI


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
            name: "Motrix WebExtension",
            license: "GPL-3.0",
            description: "Browser extension for capturing downloads.\nhttps://github.com/gautamkrishnar/motrix-webextension",
            type: "Tooling"
        )
    ]
    @State private var changelogs: [ChangelogItem] = [
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
                    
                    Link(destination: URL(string: "https://github.com/agalwood/Motrix")!) {
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
