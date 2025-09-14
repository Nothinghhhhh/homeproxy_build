# HomeProxy IPK 执行构建脚本
# 修复版本，解决语法问题

param(
    [switch]$CheckOnly
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-DockerInstallation {
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Docker已安装: $dockerVersion" "Green"
            return $true
        }
    } catch {
        Write-ColorOutput "❌ Docker未安装或未启动" "Red"
        return $false
    }
    return $false
}

Write-ColorOutput "🏠 HomeProxy IPK 构建执行器" "Green"
Write-ColorOutput "================================`n" "Green"

# 检查Docker
$dockerAvailable = Test-DockerInstallation

if (-not $dockerAvailable) {
    Write-ColorOutput "❌ Docker不可用，请先安装Docker Desktop" "Red"
    Write-ColorOutput "`n📥 Docker Desktop下载地址:" "Yellow"
    Write-ColorOutput "https://www.docker.com/products/docker-desktop" "Cyan"
    Write-ColorOutput "`n安装完成后请重新运行此脚本" "Yellow"
    
    # 尝试打开下载页面
    Write-Host "是否打开Docker下载页面? (Y/n): " -NoNewline
    $response = Read-Host
    if ($response -ne 'n' -and $response -ne 'N') {
        Start-Process "https://www.docker.com/products/docker-desktop"
    }
    exit 1
}

if ($CheckOnly) {
    Write-ColorOutput "✅ 环境检查通过，Docker可用" "Green"
    exit 0
}

# 开始构建流程
Write-ColorOutput "🚀 开始构建流程..." "Yellow"

# 检查Docker服务
try {
    docker info | Out-Null
    Write-ColorOutput "✅ Docker服务运行正常" "Green"
} catch {
    Write-ColorOutput "❌ Docker服务未启动，请启动Docker Desktop" "Red"
    exit 1
}

# 创建输出目录
Write-ColorOutput "📁 准备构建环境..." "Yellow"
if (Test-Path "build-result") {
    Remove-Item "build-result" -Recurse -Force
}
New-Item -ItemType Directory -Path "build-result" | Out-Null

# 创建Dockerfile内容
$dockerfileContent = @'
FROM openwrt/sdk:mediatek-filogic-23.05.3

WORKDIR /build

COPY Makefile ./package/luci-app-homeproxy/
COPY htdocs ./package/luci-app-homeproxy/htdocs/
COPY po ./package/luci-app-homeproxy/po/
COPY root ./package/luci-app-homeproxy/root/

RUN ./scripts/feeds update luci
RUN ./scripts/feeds install luci
RUN echo 'CONFIG_PACKAGE_luci-app-homeproxy=m' > .config
RUN make defconfig
RUN make package/luci-app-homeproxy/compile V=s
RUN mkdir -p /output
RUN find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} /output/ \;
RUN ls -la /output/

CMD ["sh"]
'@

# 写入Dockerfile
$dockerfileContent | Out-File -FilePath "Dockerfile.exec" -Encoding UTF8

Write-ColorOutput "🔨 开始Docker构建..." "Yellow"
Write-ColorOutput "预计耗时: 10-20分钟，请耐心等待..." "Gray"

$buildStartTime = Get-Date

try {
    # 构建镜像
    Write-ColorOutput "📦 正在构建Docker镜像..." "Yellow"
    docker build -f Dockerfile.exec -t homeproxy-exec:latest . 2>&1 | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Docker镜像构建失败" "Red"
        exit 1
    }
    
    Write-ColorOutput "✅ Docker镜像构建完成" "Green"
    
    # 提取IPK文件
    Write-ColorOutput "📤 提取IPK文件..." "Yellow"
    docker run --rm -v "${PWD}/build-result:/host-output" homeproxy-exec:latest sh -c "cp /output/*.ipk /host-output/ 2>/dev/null || echo '正在搜索IPK文件...'; find /build/bin -name '*.ipk' -exec cp {} /host-output/ \;"
    
} catch {
    Write-ColorOutput "❌ 构建过程失败: $($_.Exception.Message)" "Red"
    exit 1
} finally {
    # 清理临时文件
    if (Test-Path "Dockerfile.exec") {
        Remove-Item "Dockerfile.exec" -Force
    }
}

$buildEndTime = Get-Date
$buildDuration = $buildEndTime - $buildStartTime

# 检查结果
Write-ColorOutput "`n📋 检查构建结果..." "Yellow"
$ipkFiles = Get-ChildItem -Path "build-result" -Filter "*.ipk" -ErrorAction SilentlyContinue

if ($ipkFiles.Count -eq 0) {
    Write-ColorOutput "❌ 未找到IPK文件，构建可能失败" "Red"
    
    # 尝试手动检查
    Write-ColorOutput "🔍 尝试手动检查构建输出..." "Yellow"
    docker run --rm homeproxy-exec:latest find /build -name "*.ipk" 2>/dev/null | ForEach-Object {
        Write-ColorOutput "发现: $_" "Gray"
    }
    exit 1
}

# 成功输出
Write-ColorOutput "`n🎉 构建成功完成!" "Green"
Write-ColorOutput "==============================" "Green"
Write-ColorOutput "📊 构建统计:" "Yellow"
Write-ColorOutput "  构建时间: $($buildDuration.ToString('mm\:ss'))" "Cyan"
Write-ColorOutput "  文件数量: $($ipkFiles.Count)" "Cyan"

Write-ColorOutput "`n📦 生成的IPK文件:" "Yellow"
foreach ($file in $ipkFiles) {
    $sizeKB = [math]::Round($file.Length / 1KB, 2)
    Write-ColorOutput "  📄 $($file.Name)" "Cyan"
    Write-ColorOutput "     大小: ${sizeKB} KB" "Gray"
    Write-ColorOutput "     路径: $($file.FullName)" "Gray"
    
    # 计算文件哈希
    $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
    Write-ColorOutput "     SHA256: $($hash.Hash.ToLower())" "DarkGray"
}

Write-ColorOutput "`n📝 安装指南:" "Yellow"
Write-ColorOutput "1. 将IPK文件传输到软路由设备" "White"
Write-ColorOutput "2. 在设备上执行:" "White"
Write-ColorOutput "   opkg update" "Cyan"
Write-ColorOutput "   opkg install luci-app-homeproxy_*.ipk" "Cyan"
Write-ColorOutput "3. 重启Web服务:" "White"
Write-ColorOutput "   /etc/init.d/uhttpd restart" "Cyan"
Write-ColorOutput "4. 访问Web界面:" "White"
Write-ColorOutput "   http://路由器IP/cgi-bin/luci/admin/services/homeproxy" "Cyan"

# 打开结果目录
Write-ColorOutput "`n🎊 构建完成!" "Green"
Write-Host "是否打开结果目录? (Y/n): " -NoNewline
$openResult = Read-Host
if ($openResult -ne 'n' -and $openResult -ne 'N') {
    Start-Process explorer.exe -ArgumentList "build-result"
}

Write-ColorOutput "感谢使用HomeProxy构建工具!" "Green"
