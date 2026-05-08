#!/bin/bash
# llama-vulkan-full-setup.sh - 一键安装 Vulkan + GPU 驱动脚本
# 支持 NVIDIA RTX 3060 和 AMD MI50 双 GPU 配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测操作系统类型
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        log_info "检测到 macOS 系统"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE="$ID"
        log_info "检测到 Linux 系统: $ID"
    else
        OS_TYPE="unknown"
        log_error "无法识别操作系统"
        exit 1
    fi
}

# macOS 安装
install_macos() {
    log_info "开始 macOS Vulkan 安装..."
    
    # 检查 Homebrew
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew 未安装，请先安装 Homebrew:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # 安装 Vulkan 工具
    log_info "安装 Vulkan 工具..."
    brew update
    brew install vulkan-headers vulkan-tools vulkan-validation-layers
    
    # 安装 MoltenVK (macOS Vulkan 实现)
    log_info "安装 MoltenVK..."
    brew install molten-vk
    
    # 安装 llama.cpp
    log_info "安装 llama.cpp..."
    brew install llama.cpp
    
    log_success "macOS Vulkan 配置完成!"
    echo ""
    echo "验证安装:"
    echo "  vulkaninfo --summary"
    echo "  llama-cli --help"
}

# Ubuntu/Debian 安装
install_ubuntu() {
    log_info "开始 Ubuntu/Debian Vulkan 安装..."
    
    # 更新包列表
    log_info "更新包列表..."
    sudo apt update
    
    # 安装基础 Vulkan 工具（兼容不同 Ubuntu 版本）
    log_info "安装 Vulkan 基础工具..."
    
    # Ubuntu 24.04 (noble) 及更新版本包名变更
    # vulkan-icd-loader 已被废弃，vulkan-tools 包含所需功能
    # libgl1-mesa-glx 和 libegl1-mesa 被 libgl1 和 libegl1 替代
    
    # 尝试安装新包名（Ubuntu 24.04+）
    if apt-cache search libgl1 | grep -q "^libgl1 "; then
        log_info "检测到 Ubuntu 24.04+，使用新包名..."
        sudo apt install -y \
            vulkan-tools \
            libvulkan1 \
            mesa-vulkan-drivers \
            libgl1 \
            libegl1 \
            libgl1-mesa-dri \
            libegl-mesa0 || true
    else
        # 旧版本 Ubuntu/Debian
        sudo apt install -y \
            vulkan-tools \
            vulkan-icd-loader \
            libvulkan1 \
            mesa-vulkan-drivers \
            libgl1-mesa-glx \
            libegl1-mesa || true
    fi
    
    # 检测 GPU 类型
    GPU_DETECTED=""
    
    # 检测 NVIDIA GPU
    if lspci | grep -i "nvidia" > /dev/null 2>&1; then
        GPU_DETECTED="nvidia"
        log_info "检测到 NVIDIA GPU，安装驱动..."
        
        # 添加 NVIDIA 驱动 PPA
        sudo add-apt-repository ppa:graphics-drivers/ppa -y
        sudo apt update
        
        # 安装 NVIDIA 驱动（推荐 535+ 版本）
        log_info "安装 NVIDIA 驱动 535..."
        sudo apt install -y nvidia-driver-535
        
        # 安装 CUDA Toolkit (可选，用于 llama.cpp CUDA 后端)
        log_warning "CUDA Toolkit 可选安装（如需 CUDA 后端支持）"
        read -p "是否安装 CUDA Toolkit? [y/N]: " cuda_install
        if [[ "$cuda_install" =~ ^[Yy]$ ]]; then
            sudo apt install -y nvidia-cuda-toolkit
        fi
    fi
    
    # 检测 AMD GPU
    if lspci | grep -i "amd" > /dev/null 2>&1 || lspci | grep -i "rasen" > /dev/null 2>&1; then
        GPU_DETECTED="amd"
        log_info "检测到 AMD GPU，安装驱动..."
        
        # 安装 AMD Vulkan 驱动
        # 注意：vulkan-radeon 和 libvulkan-radeon 需要 AMD 官方仓库
        # 如果不可用，使用 mesa-vulkan-drivers 作为回退
        log_info "安装 AMD Vulkan 驱动..."
        
        # 先尝试安装基础驱动（总是可用）
        sudo apt install -y mesa-vulkan-drivers \
            libvulkan1
        
        # 尝试安装 AMD 专有驱动（如果仓库可用）
        if apt-cache search vulkan-radeon | grep -q "^vulkan-radeon"; then
            log_info "检测到 AMD 仓库，安装专有驱动..."
            sudo apt install -y vulkan-radeon libvulkan-radeon
        else
            log_warning "vulkan-radeon 包不可用，使用 mesa-vulkan-drivers（开源驱动已包含 Vulkan 支持）"
            log_info "如需 AMD 专有驱动，请先添加 AMD 软件源：https://www.amd.com/en/support/linux-drivers"
        fi
        
        # MI50 (gfx906) 特殊配置
        if lspci | grep -i "MI50" > /dev/null 2>&1; then
            log_info "检测到 AMD MI50，配置 gfx906 支持..."
            
            # 创建 ROCm 配置文件
            echo "export HSA_OVERRIDE_GFX_VERSION=9.0.6" | sudo tee -a /etc/profile.d/rocm.sh
            sudo chmod +x /etc/profile.d/rocm.sh
            
            log_success "MI50 gfx906 配置完成"
        fi
    fi
    
    # 安装 llama.cpp
    log_info "安装 llama.cpp..."
    
    # llama-cpp 包在大多数 Ubuntu 源中不可用，直接从源码编译
    log_info "从源码编译 llama.cpp..."
    
    # 安装编译依赖
    sudo apt install -y \
        build-essential \
        cmake \
        git \
        clang
    
    # 克隆并编译
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone https://github.com/ggml-org/llama.cpp.git
    cd llama.cpp
    
    # 创建构建目录
    mkdir -p build && cd build
    
    # 配置编译选项
    if [[ "$GPU_DETECTED" == "nvidia" ]]; then
        log_info "启用 CUDA 后端..."
        cmake -DLLAMA_CUDA=ON ..
    elif [[ "$GPU_DETECTED" == "amd" ]]; then
        log_info "启用 Vulkan 后端..."
        cmake -DLLAMA_VULKAN=ON ..
    else
        cmake ..
    fi
    
    # 编译
    make -j$(nproc)
    
    # 安装
    sudo make install
    
    # 清理临时目录
    cd /
    rm -rf "$TEMP_DIR"
    
    log_success "Ubuntu/Debian Vulkan 配置完成!"
}

# CentOS/Fedora 安装
install_centos() {
    log_info "开始 CentOS/Fedora Vulkan 安装..."
    
    if [ -f /etc/fedora-release ]; then
        # Fedora
        dnf update -y
        dnf install -y vulkan-tools vulkan-loader vulkan-validation-layers
        
        # 安装 llama.cpp
        dnf install -y cmake git gcc-c++
        
        # 从源码编译
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        git clone https://github.com/ggml-org/llama.cpp.git
        cd llama.cpp
        mkdir -p build && cd build
        cmake -DLLAMA_VULKAN=ON ..
        make -j$(nproc)
        sudo make install
        cd /
        rm -rf "$TEMP_DIR"
        
    else
        # CentOS/RHEL
        dnf update -y
        
        # 启用 EPEL 和 RPM Fusion
        dnf install -y epel-release rpmfusion-free-release
        
        dnf install -y vulkan-tools vulkan-loader
        
        # 安装 llama.cpp
        dnf install -y cmake git gcc-c++ clang
        
        # 从源码编译
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        git clone https://github.com/ggml-org/llama.cpp.git
        cd llama.cpp
        mkdir -p build && cd build
        cmake -DLLAMA_VULKAN=ON ..
        make -j$(nproc)
        sudo make install
        cd /
        rm -rf "$TEMP_DIR"
    fi
    
    log_success "CentOS/Fedora Vulkan 配置完成!"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    echo ""
    
    # 检查 Vulkan
    if command -v vulkaninfo &> /dev/null; then
        log_success "✅ Vulkan 工具已安装"
        echo ""
        echo "Vulkan 可用 GPU 列表:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        vulkaninfo --summary 2>/dev/null | grep "deviceName" || echo "未检测到 Vulkan GPU"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_error "❌ Vulkan 工具未安装"
    fi
    
    echo ""
    
    # 检查 llama.cpp
    if command -v llama-cli &> /dev/null; then
        log_success "✅ llama.cpp 已安装"
        echo "版本: $(llama-cli --version 2>&1 | head -1)"
    else
        log_warning "⚠️  llama.cpp 未安装或使用源码路径运行"
    fi
    
    echo ""
    
    # GPU 检测
    if command -v nvidia-smi &> /dev/null; then
        log_success "✅ NVIDIA GPU 检测:"
        nvidia-smi --query-gpu=gpu_name,memory.total --format=csv 2>/dev/null | head -3
    fi
    
    if [ -d "/dev/dri" ]; then
        log_success "✅ AMD GPU 检测:"
        for card in /dev/dri/card*; do
            if [ -e "$card" ]; then
                echo "  设备：$(cat /sys/class/dri/card*/device/name 2>/dev/null | head -1)"
            fi
        done
    fi
    
    echo ""
    log_success "✅ 安装完成！"
    echo ""
    echo "下一步:"
    echo "  1. 重启系统以确保驱动加载: sudo reboot"
    echo "  2. 运行 GPU 选择器: ~/llama-vulkan-setup/gpu-selector.sh"
    echo "  3. 下载模型并开始使用"
}

# 显示使用说明
show_usage() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}    llama-vulkan-full-setup 一键安装脚本${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "用法: ./llama-vulkan-full-setup.sh"
    echo ""
    echo "支持系统:"
    echo "  - Ubuntu 18.04+"
    echo "  - Debian 10+"
    echo "  - CentOS 8+"
    echo "  - Fedora 35+"
    echo "  - macOS (需要 Homebrew)"
    echo ""
    echo "功能:"
    echo "  ✅ 自动检测操作系统类型"
    echo "  ✅ 安装 Vulkan 运行时和工具"
    echo "  ✅ 安装 GPU 驱动 (NVIDIA/AMD)"
    echo "  ✅ 配置 MI50 gfx906 特殊支持"
    echo "  ✅ 编译安装 llama.cpp (带 GPU 支持)"
    echo "  ✅ 验证安装状态"
    echo ""
}

# 主函数
main() {
    show_usage
    
    echo "开始安装，请稍候..."
    echo ""
    
    # 检测系统
    detect_os
    
    # 根据系统类型安装
    case "$OS_TYPE" in
        macos)
            install_macos
            ;;
        ubuntu|debian|pop|kali)
            install_ubuntu
            ;;
        fedora|centos|rhel|rocky|almalinux)
            install_centos
            ;;
        *)
            log_error "不支持的操作系统: $OS_TYPE"
            echo "请手动安装 Vulkan 和 llama.cpp"
            exit 1
            ;;
    esac
    
    # 验证安装
    verify_installation
    
    echo ""
    log_success "🎉 所有安装完成！"
}

# 检查 root 权限
if [ "$EUID" -ne 0 ] && [ "$OS_TYPE" != "macos" ]; then
    # 非 macOS 需要 sudo
    if command -v sudo &> /dev/null; then
        exec sudo "$0" "$@"
    else
        log_error "需要 root 权限，请使用 sudo 运行"
        echo "  sudo $0"
        exit 1
    fi
fi

# 运行主函数
main
