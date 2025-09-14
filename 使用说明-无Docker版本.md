# HomeProxy IPK 构建说明 (无Docker版本)

## 🎯 方案概述

由于您的系统上Docker不可用，我为您提供以下替代方案：

## 方案1: GitHub Actions 在线构建 (推荐)

### 步骤1: 创建GitHub仓库
1. 访问 https://github.com 并登录
2. 点击 "New repository" 创建新仓库
3. 仓库名设为: `homeproxy-build`
4. 设为Public (免费用户必须)

### 步骤2: 上传代码
1. 将整个 `luci-app-homeproxy-2024031600` 文件夹上传到仓库
2. 确保包含 `.github/workflows/build-ipk.yml` 文件

### 步骤3: 触发构建
1. 进入仓库页面
2. 点击 "Actions" 标签
3. 点击 "Build HomeProxy IPK" workflow
4. 点击 "Run workflow" 按钮
5. 等待构建完成 (约15-20分钟)

### 步骤4: 下载IPK文件
1. 构建完成后，在Actions页面点击最新的构建
2. 在 "Artifacts" 部分下载IPK文件

## 方案2: 使用在线构建服务

### Gitpod 在线IDE
1. 访问 https://gitpod.io
2. 使用GitHub账号登录
3. 新建工作区，上传代码
4. 在终端运行构建脚本

### CodeSandbox
1. 访问 https://codesandbox.io
2. 创建新的Linux环境
3. 上传代码并运行构建

## 方案3: 预构建IPK文件

如果您急需使用，我可以为您提供预构建的IPK文件下载链接。

## 方案4: 手动安装Docker

### Windows Docker Desktop 安装
1. 下载: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
2. 运行安装程序
3. 重启计算机
4. 启动Docker Desktop
5. 运行我们的构建脚本

### WSL2 + Docker 安装
1. 启用WSL2: `wsl --install`
2. 重启计算机
3. 安装Ubuntu: `wsl --install -d Ubuntu`
4. 在Ubuntu中安装Docker:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   ```
5. 运行构建脚本

## 🚀 GitHub Actions 构建配置

您的仓库中已包含 `.github/workflows/build-ipk.yml` 文件，它会自动：

1. **多平台构建**: 支持不同架构的软路由
2. **自动发布**: 构建成功后自动创建Release
3. **文件管理**: 生成的IPK文件自动打包上传

### 支持的目标平台
- `mediatek/filogic` - MediaTek MT7986/MT7981 (小米AX3000T等)
- `rockchip/armv8` - RK3568/RK3588 (软路由/NAS)
- `bcm27xx/bcm2711` - 树莓派4
- `armvirt/64` - 通用ARM64虚拟机

## 📋 构建时间对比

| 方案 | 构建时间 | 优缺点 |
|------|----------|--------|
| GitHub Actions | 15-20分钟 | ✅免费，✅自动化，❌需要GitHub账号 |
| Gitpod | 10-15分钟 | ✅在线IDE，❌有使用时间限制 |
| 本地Docker | 5-15分钟 | ✅最快，❌需要安装Docker |

## 🎊 推荐流程

1. **立即使用**: 选择GitHub Actions方案
2. **长期开发**: 安装Docker Desktop
3. **临时需求**: 使用预构建文件

## 📞 技术支持

如果遇到问题，请提供：
1. 选择的构建方案
2. 错误信息截图
3. 目标设备型号

---

**注意**: GitHub Actions为免费服务，每月有使用限制。对于个人项目完全够用。
