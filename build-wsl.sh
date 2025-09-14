#!/bin/bash
# 在WSL2中构建OpenWrt IPK文件的脚本

set -e

# 配置参数
TARGET="mediatek/filogic"  # 针对aarch64平台
OPENWRT_VERSION="23.05.3"
PACKAGE_NAME="luci-app-homeproxy"

echo "🚀 开始构建 $PACKAGE_NAME IPK文件..."
echo "目标平台: $TARGET"
echo "OpenWrt版本: $OPENWRT_VERSION"

# 检查必要工具
check_dependencies() {
    echo "📋 检查依赖项..."
    
    # 更新包管理器
    sudo apt update
    
    # 安装必要的依赖
    sudo apt install -y \
        build-essential \
        git \
        wget \
        curl \
        python3 \
        python3-distutils \
        zlib1g-dev \
        libssl-dev \
        libncurses5-dev \
        unzip \
        gawk \
        subversion \
        gettext \
        rsync \
        file
    
    echo "✅ 依赖项检查完成"
}

# 下载OpenWrt源码
download_openwrt() {
    echo "📥 下载OpenWrt源码..."
    
    if [ ! -d "openwrt" ]; then
        git clone --depth 1 --branch v$OPENWRT_VERSION https://github.com/openwrt/openwrt.git
    fi
    
    cd openwrt
    echo "✅ OpenWrt源码准备完成"
}

# 设置feeds
setup_feeds() {
    echo "🔧 设置feeds..."
    
    # 更新feeds配置
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    
    echo "✅ Feeds设置完成"
}

# 复制包文件
copy_package() {
    echo "📁 复制包文件..."
    
    # 创建包目录
    PKG_DIR="package/luci-app-homeproxy"
    rm -rf "$PKG_DIR"
    mkdir -p "$PKG_DIR"
    
    # 复制源文件
    cp -r "../Makefile" "$PKG_DIR/"
    cp -r "../htdocs" "$PKG_DIR/"
    cp -r "../po" "$PKG_DIR/"
    cp -r "../root" "$PKG_DIR/"
    
    echo "✅ 包文件复制完成"
}

# 配置构建
configure_build() {
    echo "⚙️ 配置构建..."
    
    # 生成基础配置
    make defconfig
    
    # 设置目标平台
    echo "CONFIG_TARGET_$(echo $TARGET | tr '/' '_')=y" >> .config
    
    # 启用我们的包
    echo "CONFIG_PACKAGE_luci-app-homeproxy=m" >> .config
    
    # 重新生成配置
    make defconfig
    
    echo "✅ 构建配置完成"
}

# 编译包
build_package() {
    echo "🔨 开始编译..."
    
    # 只编译我们的包
    make package/luci-app-homeproxy/compile V=s
    
    echo "✅ 编译完成"
}

# 收集输出文件
collect_output() {
    echo "📦 收集输出文件..."
    
    # 创建输出目录
    OUTPUT_DIR="../build-output"
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    # 查找并复制IPK文件
    find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} "$OUTPUT_DIR/" \;
    
    # 列出生成的文件
    echo "🎉 生成的IPK文件:"
    ls -la "$OUTPUT_DIR"/*.ipk
    
    echo "✅ 文件收集完成"
}

# 主函数
main() {
    echo "🏁 开始构建流程..."
    
    check_dependencies
    download_openwrt
    setup_feeds
    copy_package
    configure_build
    build_package
    collect_output
    
    echo "🎊 构建完成！IPK文件已生成到 build-output 目录"
}

# 运行主函数
main "$@"
