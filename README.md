# MotrixMac

> This is a vibe-coded project.
> Developed with ❤️ using **Antigravity**.

<p align="center">
  <img src="./pics/icon.png" width="128" alt="MotrixMac Icon" />
</p>

## A lightweight, native Swift-powered download manager for macOS.

English | [简体中文](./README-CN.md)

## Why MotrixMac?

The original [Motrix](https://github.com/agalwood/Motrix) project has served many users well, but it hasn't seen frequent updates for quite some time. MotrixMac was born out of a desire to rejuvenate that experience by rebuilding it from the ground up using **Swift** and **SwiftUI**. 

Our goal is to provide a truly native, lightweight, and high-performance download manager specifically optimized for the modern macOS ecosystem.

MotrixMac is a native macOS download manager built with SwiftUI, designed for speed, efficiency, and a premium user experience. It captures the essence of the original Motrix while delivering a truly native feel.

## ✨ Features

- 🕹 **Fully Native**: Built with Swift and SwiftUI for maximum performance and macOS integration.
- 🦄 **Broad Support**: Supports HTTP, FTP, BitTorrent, and Magnet links.
- 📡 **Auto Trackers**: Automatically updates tracker lists daily for better BT connectivity.
- 🚀 **High Performance**: Supports up to 128 threads per task for blazing-fast downloads.
- 🔌 **Universal Connectivity**: Integrated UPnP & NAT-PMP port mapping.
- 🌍 **Browser Integration**: Comes with a robust WebExtension for Chrome and Edge.
- 🌑 **Modern Design**: Support for Dark Mode and a sleek, translucent "Liquid Glass" UI.
- 🗑 **Smart Cleanup**: Option to delete associated files when removing tasks.

## 🖥 Screenshots

![Task List](./pics/screenshot-1.png)
![Task Details](./pics/screenshot-2.png)
![Menu Bar](./pics/screenshot-3.png)

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
- Developed using [Antigravity](https://antigravity.google/), the powerful AI coding assistant by Google DeepMind.

## 📜 License

[MIT](https://opensource.org/license/MIT) Copyright (c) 2026-present Shawn Rain
