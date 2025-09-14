# HomeProxy IPK 完全自动化构建脚本
# 适用于Windows Docker环境

param(
    [string]$Target = "mediatek/filogic",
    [string]$Subtarget = "generic", 
    [string]$OpenWrtVersion = "23.05.3"
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "🚀 HomeProxy IPK 完全自动化构建工具" "Green"
Write-ColorOutput "===========================================`n" "Green"

Write-ColorOutput "📋 构建配置:" "Yellow"
Write-ColorOutput "  目标平台: $Target" "Cyan"
Write-ColorOutput "  子目标: $Subtarget" "Cyan"
Write-ColorOutput "  OpenWrt版本: $OpenWrtVersion`n" "Cyan"

# 检查Docker环境
Write-ColorOutput "🔍 检查Docker环境..." "Yellow"
try {
    $dockerVersion = docker --version
    Write-ColorOutput "✅ Docker已安装: $dockerVersion" "Green"
} catch {
    Write-ColorOutput "❌ Docker未安装或未启动！请安装Docker Desktop并启动" "Red"
    Write-ColorOutput "下载地址: https://www.docker.com/products/docker-desktop" "Yellow"
    exit 1
}

# 清理之前的构建
Write-ColorOutput "🧹 清理之前的构建文件..." "Yellow"
$directories = @("build-workspace", "build-output", "temp-docker")
foreach ($dir in $directories) {
    if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force
        Write-ColorOutput "  删除目录: $dir" "Gray"
    }
}

# 创建构建工作空间
Write-ColorOutput "📁 创建构建工作空间..." "Yellow"
New-Item -ItemType Directory -Path "build-workspace" -Force | Out-Null
New-Item -ItemType Directory -Path "build-output" -Force | Out-Null
New-Item -ItemType Directory -Path "temp-docker" -Force | Out-Null

# 准备包文件
Write-ColorOutput "📦 准备包文件..." "Yellow"
$packageDir = "build-workspace/package/luci-app-homeproxy"
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

Copy-Item -Path "Makefile" -Destination $packageDir -Force
Copy-Item -Path "htdocs" -Destination $packageDir -Recurse -Force
Copy-Item -Path "po" -Destination $packageDir -Recurse -Force
Copy-Item -Path "root" -Destination $packageDir -Recurse -Force

Write-ColorOutput "✅ 包文件准备完成" "Green"

# 创建优化的Dockerfile
Write-ColorOutput "🐳 创建Docker构建环境..." "Yellow"

$dockerfileContent = @"
FROM ubuntu:20.04

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装必要的依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    flex \
    bison \
    g++ \
    gawk \
    gcc-multilib \
    g++-multilib \
    gettext \
    git \
    libncurses5-dev \
    libssl-dev \
    python3-distutils \
    rsync \
    unzip \
    zlib1g-dev \
    file \
    wget \
    curl \
    subversion \
    python3 \
    python3-setuptools \
    python3-dev \
    xz-utils \
    time \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /build

# 下载OpenWrt源码
RUN git clone --depth 1 --branch v$OpenWrtVersion https://github.com/openwrt/openwrt.git

WORKDIR /build/openwrt

# 复制包文件
COPY build-workspace/package ./package/

# 更新feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install -a

# 创建构建脚本
RUN echo '#!/bin/bash' > /build/build.sh && \
    echo 'set -e' >> /build/build.sh && \
    echo 'cd /build/openwrt' >> /build/build.sh && \
    echo 'make defconfig' >> /build/build.sh && \
    echo 'echo "CONFIG_TARGET_${TARGET/\//_}=y" >> .config' >> /build/build.sh && \
    echo 'echo "CONFIG_TARGET_${TARGET/\//_}_${SUBTARGET}=y" >> .config' >> /build/build.sh && \
    echo 'echo "CONFIG_PACKAGE_luci-app-homeproxy=m" >> .config' >> /build/build.sh && \
    echo 'make defconfig' >> /build/build.sh && \
    echo 'make package/luci-app-homeproxy/compile V=s' >> /build/build.sh && \
    echo 'mkdir -p /output' >> /build/build.sh && \
    echo 'find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} /output/ \;' >> /build/build.sh && \
    echo 'ls -la /output/' >> /build/build.sh && \
    chmod +x /build/build.sh

# 设置环境变量
ENV TARGET=$Target
ENV SUBTARGET=$Subtarget

CMD ["/build/build.sh"]
"@

$dockerfileContent | Out-File -FilePath "temp-docker/Dockerfile" -Encoding UTF8

Write-ColorOutput "✅ Dockerfile创建完成" "Green"

# 构建Docker镜像
Write-ColorOutput "🔨 构建Docker镜像..." "Yellow"
Write-ColorOutput "这可能需要10-20分钟，请耐心等待..." "Yellow"

$buildStartTime = Get-Date

try {
    docker build -t homeproxy-builder:latest -f temp-docker/Dockerfile .
    Write-ColorOutput "✅ Docker镜像构建完成" "Green"
} catch {
    Write-ColorOutput "❌ Docker镜像构建失败!" "Red"
    Write-ColorOutput "错误信息: $($_.Exception.Message)" "Red"
    exit 1
}

# 运行构建
Write-ColorOutput "⚡ 开始编译IPK包..." "Yellow"
Write-ColorOutput "编译过程中可能会有大量输出，这是正常的..." "Gray"

$buildOutput = ""
try {
    $buildOutput = docker run --rm -v "${PWD}/build-output:/output" homeproxy-builder:latest 2>&1
    Write-ColorOutput "✅ 编译完成" "Green"
} catch {
    Write-ColorOutput "❌ 编译失败!" "Red"
    Write-ColorOutput "错误信息: $($_.Exception.Message)" "Red"
    Write-ColorOutput "构建输出:" "Yellow"
    Write-ColorOutput $buildOutput "Gray"
    exit 1
}

$buildEndTime = Get-Date
$buildDuration = $buildEndTime - $buildStartTime

# 检查构建结果
Write-ColorOutput "`n📋 检查构建结果..." "Yellow"

$ipkFiles = Get-ChildItem -Path "build-output" -Filter "*.ipk" -ErrorAction SilentlyContinue

if ($ipkFiles.Count -eq 0) {
    Write-ColorOutput "❌ 未找到生成的IPK文件!" "Red"
    Write-ColorOutput "尝试显示构建日志的最后100行:" "Yellow"
    $buildOutput -split "`n" | Select-Object -Last 100 | ForEach-Object { Write-ColorOutput $_ "Gray" }
    exit 1
}

# 显示构建成功信息
Write-ColorOutput "`n🎉 构建成功完成!" "Green"
Write-ColorOutput "===============================================" "Green"
Write-ColorOutput "📊 构建统计:" "Yellow"
Write-ColorOutput "  构建时间: $($buildDuration.ToString('mm\:ss'))" "Cyan"
Write-ColorOutput "  生成文件数: $($ipkFiles.Count)" "Cyan"

Write-ColorOutput "`n📦 生成的IPK文件:" "Yellow"
foreach ($file in $ipkFiles) {
    $sizeKB = [math]::Round($file.Length / 1KB, 2)
    $sizeMB = [math]::Round($file.Length / 1MB, 2)
    Write-ColorOutput "  📄 $($file.Name)" "Cyan"
    Write-ColorOutput "     大小: ${sizeKB} KB (${sizeMB} MB)" "Gray"
    Write-ColorOutput "     路径: $($file.FullName)" "Gray"
}

# 生成安装说明
Write-ColorOutput "`n📝 安装说明:" "Yellow"
Write-ColorOutput "1. 将IPK文件传输到您的软路由设备" "White"
Write-ColorOutput "2. 在设备上运行以下命令:" "White"
Write-ColorOutput "   opkg update" "Cyan"
Write-ColorOutput "   opkg install /path/to/luci-app-homeproxy_*.ipk" "Cyan"
Write-ColorOutput "3. 重启luci服务:" "White"
Write-ColorOutput "   /etc/init.d/uhttpd restart" "Cyan"

# 生成SHA256校验和
Write-ColorOutput "`n🔐 文件校验和:" "Yellow"
foreach ($file in $ipkFiles) {
    $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
    Write-ColorOutput "  $($file.Name)" "Cyan"
    Write-ColorOutput "  SHA256: $($hash.Hash.ToLower())" "Gray"
}

# 清理临时文件
Write-ColorOutput "`n🧹 清理临时文件..." "Yellow"
Remove-Item -Path "build-workspace" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "temp-docker" -Recurse -Force -ErrorAction SilentlyContinue

# 清理Docker镜像（可选）
Write-ColorOutput "是否删除Docker镜像以节省空间? (y/N): " "Yellow" -NoNewline
$cleanup = Read-Host
if ($cleanup -eq 'y' -or $cleanup -eq 'Y') {
    docker rmi homeproxy-builder:latest -f | Out-Null
    Write-ColorOutput "✅ Docker镜像已删除" "Green"
}

Write-ColorOutput "`n🎊 全部完成!" "Green"
Write-ColorOutput "IPK文件位置: $(Resolve-Path 'build-output')" "Yellow"

# 询问是否打开输出目录
Write-ColorOutput "`n是否打开输出目录? (Y/n): " "Yellow" -NoNewline
$openDir = Read-Host
if ($openDir -ne 'n' -and $openDir -ne 'N') {
    Start-Process explorer.exe -ArgumentList "build-output"
}
