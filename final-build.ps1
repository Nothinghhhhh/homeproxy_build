Write-Host "HomeProxy IPK构建工具" -ForegroundColor Green

# 创建简单的Dockerfile
$content = @"
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
"@

$content | Out-File -FilePath "Dockerfile" -Encoding ASCII

# 创建输出目录
if (Test-Path "result") { 
    Remove-Item "result" -Recurse -Force 
}
New-Item -ItemType Directory -Path "result" | Out-Null

Write-Host "开始构建..." -ForegroundColor Yellow

# 构建镜像
docker build -t hp-build .

# 运行并提取文件
docker run --rm -v "${PWD}/result:/host" hp-build sh -c "cp /output/* /host/"

# 检查结果
$files = Get-ChildItem -Path "result" -Filter "*.ipk"
if ($files.Count -gt 0) {
    Write-Host "SUCCESS!" -ForegroundColor Green
    $files | ForEach-Object { Write-Host $_.Name -ForegroundColor Cyan }
} else {
    Write-Host "FAILED" -ForegroundColor Red
}

Remove-Item "Dockerfile"
