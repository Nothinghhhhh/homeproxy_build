# 快速构建脚本 - 使用预编译的SDK
param(
    [string]$SDK_URL = "https://downloads.openwrt.org/releases/23.05.3/targets/mediatek/filogic/openwrt-sdk-23.05.3-mediatek-filogic_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
)

Write-Host "🚀 HomeProxy IPK 快速构建工具" -ForegroundColor Green
Write-Host "适用于Windows + Docker环境" -ForegroundColor Yellow

# 检查Docker
try {
    docker --version | Out-Null
    Write-Host "✅ Docker已就绪" -ForegroundColor Green
} catch {
    Write-Host "❌ 请安装Docker Desktop" -ForegroundColor Red
    exit 1
}

# 创建临时构建脚本
@"
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装依赖
RUN apt-get update && apt-get install -y \
    build-essential git wget curl python3 python3-distutils \
    zlib1g-dev libssl-dev libncurses5-dev unzip gawk \
    subversion gettext rsync file xz-utils && \
    rm -rf /var/lib/apt/lists/*

# 下载并解压SDK
WORKDIR /build
RUN wget -O sdk.tar.xz "$SDK_URL" && \
    tar -xJf sdk.tar.xz && \
    rm sdk.tar.xz

# 设置工作目录
RUN mv openwrt-sdk-* sdk
WORKDIR /build/sdk

# 复制包文件
COPY . package/luci-app-homeproxy/

# 构建
RUN ./scripts/feeds update luci && \
    ./scripts/feeds install luci && \
    echo 'CONFIG_PACKAGE_luci-app-homeproxy=m' > .config && \
    make defconfig && \
    make package/luci-app-homeproxy/compile V=s

# 收集输出
RUN mkdir -p /output && \
    find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} /output/ \;

CMD ["ls", "-la", "/output/"]
"@ | Out-File -FilePath "Dockerfile.quick" -Encoding UTF8

Write-Host "🔨 开始快速构建..." -ForegroundColor Yellow

# 构建
$OUTPUT_DIR = "quick-build-output"
if (Test-Path $OUTPUT_DIR) {
    Remove-Item -Path $OUTPUT_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null

docker build -f Dockerfile.quick -t homeproxy-quick .
docker run --rm -v "${PWD}/${OUTPUT_DIR}:/output" homeproxy-quick sh -c "cp /build/sdk/bin/packages/*/luci/*luci-app-homeproxy*.ipk /output/ 2>/dev/null || echo 'Finding IPK files...'; find /build/sdk/bin/ -name '*luci-app-homeproxy*.ipk' -exec cp {} /output/ \;"

# 检查结果
$IPK_FILES = Get-ChildItem -Path $OUTPUT_DIR -Filter "*.ipk" -ErrorAction SilentlyContinue
if ($IPK_FILES.Count -gt 0) {
    Write-Host "✅ 快速构建成功！" -ForegroundColor Green
    Write-Host "生成的IPK文件:" -ForegroundColor Yellow
    foreach ($file in $IPK_FILES) {
        $size = [math]::Round($file.Length / 1KB, 2)
        Write-Host "  📦 $($file.Name) (${size} KB)" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ 构建失败或未找到IPK文件" -ForegroundColor Red
    Write-Host "尝试查看构建日志..." -ForegroundColor Yellow
    docker run --rm homeproxy-quick find /build/sdk/bin/ -name "*.ipk"
}

# 清理
Remove-Item -Path "Dockerfile.quick" -Force -ErrorAction SilentlyContinue

Write-Host "🎉 构建完成！" -ForegroundColor Green
