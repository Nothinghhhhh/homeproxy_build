# HomeProxy 环境设置和构建脚本
# 包含Docker检查、安装指导和完整构建流程

param(
    [switch]$CheckOnly,
    [switch]$InstallDocker,
    [switch]$Build
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-DockerInstallation {
    try {
        $dockerPath = Get-Command docker -ErrorAction Stop
        $dockerVersion = & docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Docker已安装: $dockerVersion" "Green"
            return $true
        }
    } catch {
        Write-ColorOutput "❌ Docker未安装或未在PATH中" "Red"
        return $false
    }
    return $false
}

function Install-DockerDesktop {
    Write-ColorOutput "🔽 开始下载Docker Desktop..." "Yellow"
    
    $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
    
    try {
        Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath -UseBasicParsing
        Write-ColorOutput "✅ Docker Desktop下载完成" "Green"
        
        Write-ColorOutput "🚀 启动Docker Desktop安装..." "Yellow"
        Start-Process -FilePath $installerPath -Wait
        
        Write-ColorOutput "✅ Docker Desktop安装完成" "Green"
        Write-ColorOutput "⚠️  请重启计算机后再运行构建脚本" "Yellow"
        
    } catch {
        Write-ColorOutput "❌ Docker Desktop下载失败: $($_.Exception.Message)" "Red"
        Write-ColorOutput "请手动下载安装: https://www.docker.com/products/docker-desktop" "Yellow"
    }
}

function Start-Build {
    Write-ColorOutput "🚀 开始构建HomeProxy IPK..." "Green"
    
    # 创建简化的构建Dockerfile
    $simpleDockerfile = @"
FROM openwrt/sdk:mediatek-filogic-23.05.3

# 设置工作目录
WORKDIR /build

# 复制源码文件
COPY Makefile ./package/luci-app-homeproxy/
COPY htdocs ./package/luci-app-homeproxy/htdocs/
COPY po ./package/luci-app-homeproxy/po/
COPY root ./package/luci-app-homeproxy/root/

# 更新feeds并安装luci
RUN ./scripts/feeds update luci && \
    ./scripts/feeds install luci

# 配置构建
RUN echo 'CONFIG_PACKAGE_luci-app-homeproxy=m' > .config && \
    make defconfig

# 构建包
RUN make package/luci-app-homeproxy/compile V=s

# 创建输出目录并复制IPK文件
RUN mkdir -p /output && \
    find bin/ -name "*luci-app-homeproxy*.ipk" -exec cp {} /output/ \;

# 显示构建结果
RUN ls -la /output/

CMD ["sh"]
"@

    $simpleDockerfile | Out-File -FilePath "Dockerfile.build" -Encoding UTF8
    
    Write-ColorOutput "📦 创建构建环境..." "Yellow"
    
    try {
        # 构建Docker镜像
        Write-ColorOutput "正在构建Docker镜像，这可能需要10-20分钟..." "Gray"
        docker build -f Dockerfile.build -t homeproxy-builder . | Out-Host
        
        Write-ColorOutput "✅ 构建环境创建完成" "Green"
        
        # 创建输出目录
        if (Test-Path "final-output") {
            Remove-Item "final-output" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "final-output" | Out-Null
        
        # 运行构建并提取文件
        Write-ColorOutput "📤 提取IPK文件..." "Yellow"
        docker run --rm -v "${PWD}/final-output:/host-output" homeproxy-builder sh -c "cp /output/*.ipk /host-output/ 2>/dev/null || echo 'Searching for IPK files...'; find /build/bin -name '*.ipk' -exec cp {} /host-output/ \;"
        
        # 检查结果
        $ipkFiles = Get-ChildItem -Path "final-output" -Filter "*.ipk" -ErrorAction SilentlyContinue
        
        if ($ipkFiles.Count -gt 0) {
            Write-ColorOutput "`n🎉 构建成功!" "Green"
            Write-ColorOutput "============================================" "Green"
            Write-ColorOutput "📦 生成的IPK文件:" "Yellow"
            
            foreach ($file in $ipkFiles) {
                $size = [math]::Round($file.Length / 1KB, 2)
                Write-ColorOutput "  📄 $($file.Name) (${size} KB)" "Cyan"
                
                # 计算SHA256
                $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
                Write-ColorOutput "     SHA256: $($hash.Hash.ToLower())" "Gray"
            }
            
            Write-ColorOutput "`n📝 安装说明:" "Yellow"
            Write-ColorOutput "1. 将IPK文件上传到您的软路由设备" "White"
            Write-ColorOutput "2. 在设备上执行: opkg install luci-app-homeproxy_*.ipk" "Cyan"
            Write-ColorOutput "3. 重启Web服务: /etc/init.d/uhttpd restart" "Cyan"
            Write-ColorOutput "4. 访问: http://路由器IP/cgi-bin/luci/admin/services/homeproxy" "Cyan"
            
            # 打开输出目录
            Start-Process explorer.exe -ArgumentList "final-output"
            
        } else {
            Write-ColorOutput "❌ 未找到IPK文件，构建可能失败" "Red"
            Write-ColorOutput "尝试查看详细日志..." "Yellow"
            docker run --rm homeproxy-builder find /build -name "*.ipk" | Out-Host
        }
        
    } catch {
        Write-ColorOutput "❌ 构建失败: $($_.Exception.Message)" "Red"
        return $false
    } finally {
        # 清理临时文件
        Remove-Item "Dockerfile.build" -Force -ErrorAction SilentlyContinue
    }
    
    return $true
}

# 主逻辑
Write-ColorOutput "🏠 HomeProxy IPK 构建工具" "Green"
Write-ColorOutput "适用于 aarch64 软路由设备`n" "Yellow"

# 检查Docker安装
$dockerInstalled = Test-DockerInstallation

if ($CheckOnly) {
    if ($dockerInstalled) {
        Write-ColorOutput "✅ 环境检查通过，可以开始构建" "Green"
    } else {
        Write-ColorOutput "❌ 需要先安装Docker Desktop" "Red"
    }
    exit
}

if ($InstallDocker) {
    Install-DockerDesktop
    exit
}

if ($Build -or (-not $CheckOnly -and -not $InstallDocker)) {
    if (-not $dockerInstalled) {
        Write-ColorOutput "❌ Docker未安装，无法进行构建" "Red"
        Write-ColorOutput "请先运行: .\setup-and-build.ps1 -InstallDocker" "Yellow"
        Write-ColorOutput "或手动安装Docker Desktop: https://www.docker.com/products/docker-desktop" "Yellow"
        exit 1
    }
    
    # 检查Docker服务是否运行
    try {
        docker info | Out-Null
        Write-ColorOutput "✅ Docker服务正在运行" "Green"
    } catch {
        Write-ColorOutput "❌ Docker服务未启动，请启动Docker Desktop" "Red"
        exit 1
    }
    
    $buildSuccess = Start-Build
    
    if ($buildSuccess) {
        Write-ColorOutput "`n🎊 构建完成!" "Green"
    } else {
        Write-ColorOutput "`n😞 构建失败" "Red"
        exit 1
    }
}

# 默认行为：显示使用说明
if (-not $CheckOnly -and -not $InstallDocker -and -not $Build) {
    Write-ColorOutput "📋 使用说明:" "Yellow"
    Write-ColorOutput "  检查环境: .\setup-and-build.ps1 -CheckOnly" "Cyan"
    Write-ColorOutput "  安装Docker: .\setup-and-build.ps1 -InstallDocker" "Cyan"
    Write-ColorOutput "  开始构建: .\setup-and-build.ps1 -Build" "Cyan"
    Write-ColorOutput "  一键构建: .\setup-and-build.ps1" "Cyan"
}
