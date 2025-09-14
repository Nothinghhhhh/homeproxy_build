# PowerShell脚本用于在Windows上构建OpenWrt IPK文件
# 使用Docker构建环境

param(
    [string]$TARGET = "mediatek/filogic",
    [string]$VERSION = "23.05.3"
)

Write-Host "开始构建 luci-app-homeproxy IPK 文件..." -ForegroundColor Green
Write-Host "目标平台: $TARGET" -ForegroundColor Yellow
Write-Host "OpenWrt版本: $VERSION" -ForegroundColor Yellow

# 检查Docker是否安装
try {
    docker --version | Out-Null
    Write-Host "✅ Docker已安装" -ForegroundColor Green
} catch {
    Write-Host "❌ 请先安装Docker Desktop" -ForegroundColor Red
    exit 1
}

# 创建构建目录
$BUILD_DIR = "build-output"
if (Test-Path $BUILD_DIR) {
    Remove-Item -Path $BUILD_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null

# 创建Dockerfile
@"
FROM openwrt/sdk:$TARGET-$VERSION

# 安装必要的工具
RUN opkg update && opkg install git

# 复制源码
COPY . /workdir/
WORKDIR /workdir

# 构建IPK
RUN ./scripts/feeds update luci && \
    ./scripts/feeds install luci && \
    make menuconfig < /dev/null && \
    make package/luci-app-homeproxy/compile V=s

# 创建输出目录
RUN mkdir -p /output && \
    find bin/ -name "luci-app-homeproxy*.ipk" -exec cp {} /output/ \;

CMD ["sh"]
"@ | Out-File -FilePath "Dockerfile" -Encoding UTF8

# 创建package目录结构
$PKG_DIR = "package/luci-app-homeproxy"
if (Test-Path $PKG_DIR) {
    Remove-Item -Path $PKG_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $PKG_DIR -Force | Out-Null

# 复制源码文件
Copy-Item -Path "Makefile" -Destination "$PKG_DIR/" -Force
Copy-Item -Path "htdocs" -Destination "$PKG_DIR/" -Recurse -Force
Copy-Item -Path "po" -Destination "$PKG_DIR/" -Recurse -Force  
Copy-Item -Path "root" -Destination "$PKG_DIR/" -Recurse -Force

Write-Host "🔨 开始Docker构建..." -ForegroundColor Yellow

# 构建Docker镜像
docker build -t homeproxy-builder .

# 运行容器并构建
docker run --rm -v "${PWD}/${BUILD_DIR}:/output" homeproxy-builder sh -c "
    ./scripts/feeds update luci
    ./scripts/feeds install luci
    echo 'CONFIG_PACKAGE_luci-app-homeproxy=m' > .config
    make defconfig
    make package/luci-app-homeproxy/compile V=s
    find bin/ -name 'luci-app-homeproxy*.ipk' -exec cp {} /output/ \;
"

# 检查构建结果
$IPK_FILES = Get-ChildItem -Path $BUILD_DIR -Filter "*.ipk"
if ($IPK_FILES.Count -gt 0) {
    Write-Host "✅ 构建成功！" -ForegroundColor Green
    Write-Host "生成的IPK文件:" -ForegroundColor Yellow
    foreach ($file in $IPK_FILES) {
        Write-Host "  📦 $($file.Name)" -ForegroundColor Cyan
    }
    Write-Host "文件位置: $BUILD_DIR" -ForegroundColor Yellow
} else {
    Write-Host "❌ 构建失败，未找到IPK文件" -ForegroundColor Red
    exit 1
}

# 清理临时文件
Remove-Item -Path "Dockerfile" -Force -ErrorAction SilentlyContinue
Remove-Item -Path $PKG_DIR -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "🎉 构建完成！" -ForegroundColor Green
