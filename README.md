# MotrixMac

<p align="center">
  <img src="./AppIconSet/AppIcon.iconset/icon_512x512.png" width="128" alt="MotrixMac Icon" />
</p>

## A lightweight, native Swift-powered download manager for macOS.

English | [简体中文](./README-CN.md)

MotrixMac is a native macOS download manager built with SwiftUI, designed for speed, efficiency, and a premium user experience. It captures the essence of the original Motrix while delivering a truly native feel.

## ✨ Features

- 🕹 **Fully Native**: Built with Swift and SwiftUI for maximum performance and macOS integration.
- 🦄 **Broad Support**: Supports HTTP, FTP, BitTorrent, and Magnet links.
- 📡 **Auto Trackers**: Automatically updates tracker lists daily for better BT connectivity.
- 🚀 **High Performance**: Supports up to 128 threads per task for blazing-fast downloads.
- 🔌 **Universal Connectivity**: Integrated UPnP & NAT-PMP port mapping.
- 🌍 **Browser Integration**: Comes with a robust WebExtension for Chrome, Edge, and Firefox.
- 🌑 **Modern Design**: Support for Dark Mode and a sleek, translucent "Liquid Glass" UI.
- 🗑 **Smart Cleanup**: Option to delete associated files when removing tasks.

## 🖥 Screenshots

![Main View](./MotrixMac/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1.png)

## ⌨️ Development

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/ShawnRn/MotrixMac.git
   ```
2. Open `MotrixMac.xcodeproj` in Xcode (requires macOS 14+ and Xcode 15+).
3. Build and Run.

### WebExtension

The extension logic is located in the `MotrixMac-Webextension` directory.
To build the extension:
```bash
cd MotrixMac-Webextension
yarn install
npm run build -- chrome
```

## 📜 Credits

- Inspired by [Motrix](https://github.com/agalwood/Motrix).
- Powered by [aria2](https://aria2.github.io/).
- WebExtension based on [motrix-webextension](https://github.com/gautamkrishnar/motrix-webextension).

## 📜 License

[MIT](./LICENSE) Copyright (c) 2026 Shawn Rain.
