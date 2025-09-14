# HomeProxy with Clash UI Integration

<p align="center">
  <img src="https://img.shields.io/badge/OpenWrt-23.05+-blue.svg" alt="OpenWrt">
  <img src="https://img.shields.io/badge/Arch-aarch64-green.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/License-GPL--2.0-red.svg" alt="License">
  <img src="https://github.com/Nothinghhhhh/homeproxy_build/workflows/Build%20HomeProxy%20IPK%20v2/badge.svg" alt="Build Status">
</p>

<p align="center">现代化的 <a href="https://github.com/SagerNet/sing-box" target="_blank">Sing-Box</a> 客户端，专为 OpenWrt 23.05+ 设计，集成完整的 Clash UI 功能。</p>

## ✨ 功能特性

### 🎛️ Clash UI 集成 (新增)
- **完整的 Clash API 支持**
- **Web Dashboard 可视化管理**
- **实时连接监控和统计**
- **可视化节点切换**
- **规则匹配可视化**

### 🚀 核心功能
- 支持多种代理协议：Socks5, HTTP(S), Shadowsocks, Vmess, Trojan, Wireguard, Hysteria(2), Vless, ShadowTLS, TUIC
- 基于灵活规则配置的策略代理
- DNS 分流和防污染
- 访问控制和流量管理

## 📦 快速开始

### 🔽 下载 IPK 文件

1. 访问 [Releases](https://github.com/Nothinghhhhh/homeproxy_build/releases) 页面
2. 下载适合您设备的 IPK 文件

### ⚡ 自动构建

点击 [![Build](https://img.shields.io/badge/Build-Now-brightgreen.svg)](https://github.com/Nothinghhhhh/homeproxy_build/actions/workflows/build-ipk-v2.yml) 触发自动构建

### 📱 安装方法

```bash
# 上传 IPK 文件到路由器后执行
opkg install luci-app-homeproxy_*.ipk
/etc/init.d/uhttpd restart
```

### 🌐 访问界面

安装完成后访问：`http://路由器IP/cgi-bin/luci/admin/services/homeproxy`

## 🛠️ 本地构建

### Docker 构建 (推荐)
```powershell
.\final-build.ps1
```

### GitHub Actions 构建
1. Fork 此仓库
2. 在 Actions 页面点击 "Run workflow"
3. 等待构建完成后下载 IPK 文件

## 📋 支持的设备

| 设备类型 | 目标平台 | 说明 |
|---------|---------|------|
| 小米路由器 | `mediatek/filogic` | AX3000T, AX9000 等 |
| GL.iNet | `mediatek/filogic` | MT7986 芯片系列 |
| 软路由/NAS | `rockchip/armv8` | RK3568, RK3588 等 |
| 树莓派4 | `bcm27xx/bcm2711` | Raspberry Pi 4 |
| 虚拟机 | `armvirt/64` | 通用 ARM64 |

## 📚 文档

- [构建说明](./构建说明.md)
- [使用说明-无Docker版本](./使用说明-无Docker版本.md)
- [原版 Wiki](https://github.com/douglarek/luci-app-homeproxy/wiki)

## 🤝 贡献

本项目基于 [homeproxy](https://github.com/immortalwrt/homeproxy) 开发，集成了 homeproxy-dev 分支的 Clash UI 功能。

## 📄 许可证

GPL-2.0 License
