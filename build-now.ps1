# 最简单的HomeProxy构建脚本

Write-Host "HomeProxy IPK构建工具" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

# 检查Docker
Write-Host "检查Docker..." -ForegroundColor Yellow
try {
    docker --version
    Write-Host "Docker已安装" -ForegroundColor Green
} catch {
    Write-Host "Docker未安装，请先安装Docker Desktop" -ForegroundColor Red
    Write-Host "下载地址: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# 创建Dockerfile
Write-Host "创建构建环境..." -ForegroundColor Yellow

$dockerfile = @'
FROM openwrt/sdk:mediatek-filogic-23.05.3

COPY . /src/
WORKDIR /src

RUN mkdir -p package/luci-app-homeproxy
RUN cp Makefile package/luci-app-homeproxy/
RUN cp -r htdocs package/luci-app-homeproxy/
RUN cp -r po package/luci-app-homeproxy/
RUN cp -r root package/luci-app-homeproxy/

RUN ./scripts/feeds update luci
RUN ./scripts/feeds install luci
RUN echo 'CONFIG_PACKAGE_luci-app-homeproxy=m' > .config
RUN make defconfig
RUN make package/luci-app-homeproxy/compile V=s

RUN mkdir -p /output
RUN find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} /output/ \;

CMD ["ls", "-la", "/output/"]
'@

$dockerfile | Out-File -FilePath "Dockerfile" -Encoding ASCII

# 清理旧输出
if (Test-Path "output") { Remove-Item "output" -Recurse -Force }
New-Item -ItemType Directory -Path "output" | Out-Null

Write-Host "开始构建..." -ForegroundColor Yellow
Write-Host "这可能需要15-20分钟..." -ForegroundColor Gray

# 构建
docker build -t homeproxy-build .
docker run --rm -v "${PWD}/output:/host-output" homeproxy-build sh -c "cp /output/*.ipk /host-output/ 2>/dev/null || echo 'No files found'"

# 检查结果
$files = Get-ChildItem -Path "output" -Filter "*.ipk" -ErrorAction SilentlyContinue
if ($files.Count -gt 0) {
    Write-Host "构建成功!" -ForegroundColor Green
    Write-Host "文件:" -ForegroundColor Yellow
    foreach ($f in $files) {
        Write-Host "  $($f.Name)" -ForegroundColor Cyan
    }
    explorer.exe output
} else {
    Write-Host "构建失败，未找到IPK文件" -ForegroundColor Red
}

# 清理
Remove-Item "Dockerfile" -Force
