# HomeProxy 简化Docker构建脚本
# 一键式构建，无需复杂配置

Write-Host "🚀 HomeProxy IPK 一键构建工具" -ForegroundColor Green
Write-Host "适用于 aarch64 软路由设备`n" -ForegroundColor Yellow

# 检查Docker
Write-Host "🔍 检查Docker..." -ForegroundColor Yellow
try {
    docker --version | Out-Null
    Write-Host "✅ Docker已就绪" -ForegroundColor Green
} catch {
    Write-Host "❌ 请先安装并启动Docker Desktop" -ForegroundColor Red
    exit 1
}

# 清理旧文件
Write-Host "🧹 清理旧文件..." -ForegroundColor Yellow
if (Test-Path "ipk-output") { Remove-Item "ipk-output" -Recurse -Force }
New-Item -ItemType Directory -Path "ipk-output" | Out-Null

# 创建简单的构建容器
Write-Host "📦 准备构建环境..." -ForegroundColor Yellow

$dockerfile = @"
FROM openwrt/sdk:mediatek-filogic-23.05.3

# 复制源码
COPY . /src/
WORKDIR /src

# 创建包目录并复制文件
RUN mkdir -p package/luci-app-homeproxy && \
    cp Makefile package/luci-app-homeproxy/ && \
    cp -r htdocs package/luci-app-homeproxy/ && \
    cp -r po package/luci-app-homeproxy/ && \
    cp -r root package/luci-app-homeproxy/

# 更新feeds并构建
RUN ./scripts/feeds update luci && \
    ./scripts/feeds install luci && \
    echo 'CONFIG_PACKAGE_luci-app-homeproxy=m' > .config && \
    make defconfig && \
    make package/luci-app-homeproxy/compile V=s

# 收集IPK文件
RUN mkdir -p /output && \
    find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} /output/ \;

CMD ["sh", "-c", "ls -la /output/ && echo '构建完成!'"]
"@

$dockerfile | Out-File -FilePath "Dockerfile.simple" -Encoding UTF8

Write-Host "🔨 开始构建 (预计5-15分钟)..." -ForegroundColor Yellow
Write-Host "正在下载OpenWrt SDK并编译..." -ForegroundColor Gray

$startTime = Get-Date

# 构建
try {
    docker build -f Dockerfile.simple -t homeproxy-simple . --no-cache
    Write-Host "✅ 构建环境创建完成" -ForegroundColor Green
    
    # 提取IPK文件
    docker run --rm -v "${PWD}/ipk-output:/host-output" homeproxy-simple sh -c "cp /output/*.ipk /host-output/ 2>/dev/null || echo 'No IPK files found'"
    
} catch {
    Write-Host "❌ 构建失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime

# 检查结果
$ipkFiles = Get-ChildItem -Path "ipk-output" -Filter "*.ipk" -ErrorAction SilentlyContinue

if ($ipkFiles.Count -gt 0) {
    Write-Host "`n🎉 构建成功!" -ForegroundColor Green
    Write-Host "用时: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
    Write-Host "`n📦 生成的文件:" -ForegroundColor Yellow
    
    foreach ($file in $ipkFiles) {
        $size = [math]::Round($file.Length / 1KB, 2)
        Write-Host "  📄 $($file.Name) (${size} KB)" -ForegroundColor Cyan
    }
    
    Write-Host "`n📝 安装方法:" -ForegroundColor Yellow
    Write-Host "1. 上传IPK文件到软路由" -ForegroundColor White
    Write-Host "2. 执行: opkg install luci-app-homeproxy_*.ipk" -ForegroundColor Cyan
    Write-Host "3. 重启: /etc/init.d/uhttpd restart" -ForegroundColor Cyan
    
    # 打开输出目录
    Start-Process explorer.exe -ArgumentList "ipk-output"
    
} else {
    Write-Host "❌ 未找到IPK文件，构建可能失败" -ForegroundColor Red
    Write-Host "尝试手动检查:" -ForegroundColor Yellow
    docker run --rm homeproxy-simple find /src/bin -name "*.ipk" 2>/dev/null
}

# 清理
Remove-Item "Dockerfile.simple" -Force -ErrorAction SilentlyContinue

Write-Host "`n🎊 完成!" -ForegroundColor Green
