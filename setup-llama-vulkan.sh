#!/bin/bash
#
# llama.cpp + Vulkan 一键配置脚本
# 适用于 Ubuntu 20.04/22.04/24.04
# 支持 AMD/Intel/NVIDIA GPU
#
# 使用方法:
#   chmod +x setup-llama-vulkan.sh
#   ./setup-llama-vulkan.sh
#

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查是否以 root 运行
if [ "$EUID" -eq 0 ]; then
    log_error "请不要使用 root 运行此脚本"
    log_error "请使用: ./setup-llama-vulkan.sh"
    exit 1
fi

# 检查是否为 Ubuntu/Debian
if ! command -v apt &> /dev/null; then
    log_error "此脚本仅支持 Ubuntu/Debian 系统"
    exit 1
fi

echo "============================================"
echo "  llama.cpp + Vulkan 一键配置脚本"
echo "============================================"
echo ""

# ============================================
# 步骤 1: 安装系统依赖
# ============================================
log_info "步骤 1/5: 更新系统并安装基础依赖..."

sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    git \
    libvulkan-dev \
    vulkan-tools \
    mesa-vulkan-drivers \
    python3 \
    python3-pip \
    jq \
    curl \
    libssl-dev \
    libcurl4-openssl-dev \
    xz-utils \
    libglm-dev \
    libxcb-dri3-0 \
    libxcb-present0 \
    libpciaccess0 \
    libpng-dev \
    libxcb-keysyms1-dev \
    libxcb-dri3-dev \
    libx11-dev \
    libwayland-dev \
    libxrandr-dev \
    libxcb-randr0-dev \
    libxcb-ewmh-dev \
    libx11-xcb-dev \
    liblz4-dev \
    libzstd-dev \
    ocaml-core \
    ninja-build \
    pkg-config \
    libxml2-dev \
    wayland-protocols \
    qtbase5-dev \
    qt6-base-dev

log_success "系统依赖安装完成"

# ============================================
# 步骤 2: 安装 Vulkan SDK
# ============================================
log_info "步骤 2/5: 安装 Vulkan SDK..."

# 下载 Vulkan SDK（版本可更新：https://vulkan.lunarg.com/sdk/home#linux）
VULKAN_VERSION="1.4.341.1"
VULKAN_FILENAME="vulkansdk-linux-x86_64-${VULKAN_VERSION}.tar.xz"
VULKAN_URL="https://sdk.lunarg.com/sdk/download/${VULKAN_VERSION}/linux/${VULKAN_FILENAME}"

if [ ! -f "$VULKAN_FILENAME" ]; then
    log_info "下载 Vulkan SDK ${VULKAN_VERSION}..."
    curl -L -o "$VULKAN_FILENAME" "$VULKAN_URL"
else
    log_warning "Vulkan SDK 压缩包已存在，跳过下载"
fi

# 解压
log_info "解压 Vulkan SDK..."
tar xf "$VULKAN_FILENAME"

# 创建 Vulkan 目录
mkdir -p ~/vulkan
mv "${VULKAN_VERSION}" ~/vulkan/${VULKAN_VERSION}

# 设置环境变量
export VULKAN_SDK="$HOME/vulkan/${VULKAN_VERSION}"

# 添加到 ~/.profile 以实现永久生效
if ! grep -q "vulkan/${VULKAN_VERSION}/setup-env.sh" ~/.profile 2>/dev/null; then
    echo "" >> ~/.profile
    echo "# Vulkan SDK" >> ~/..profile
    echo "export VULKAN_SDK=\"$HOME/vulkan/${VULKAN_VERSION}\"" >> ~/.profile
    echo "export PATH=\"\$VULKAN_SDK/bin:\$PATH\"" >> ~/.profile
    echo "export LD_LIBRARY_PATH=\"\$VULKAN_SDK/lib:\$LD_LIBRARY_PATH\"" >> ~/.profile
    log_info "已添加 Vulkan 环境变量到 ~/.profile"
fi

# 加载环境变量
source ~/.profile

# 复制到系统目录
log_info "配置 Vulkan 系统库..."
sudo mkdir -p /usr/local/include/vulkan
sudo cp -r $VULKAN_SDK/include/vulkan/* /usr/local/include/vulkan/ 2>/dev/null || true
sudo mkdir -p /usr/local/lib
sudo cp -P $VULKAN_SDK/lib/libvulkan.so* /usr/local/lib/ 2>/dev/null || true
sudo cp $VULKAN_SDK/lib/libVkLayer_*.so /usr/local/lib/ 2>/dev/null || true
sudo mkdir -p /usr/local/share/vulkan/explicit_layer.d
sudo cp $VULKAN_SDK/share/vulkan/explicit_layer.d/VkLayer_*.json /usr/local/share/vulkan/explicit_layer.d/ 2>/dev/null || true

# 刷新动态链接库
sudo ldconfig

log_success "Vulkan SDK 安装完成"

# ============================================
# 步骤 3: 验证 Vulkan 安装
# ============================================
log_info "步骤 3/5: 验证 Vulkan 安装..."

if command -v vulkaninfo &> /dev/null; then
    log_info "Vulkan 设备信息:"
    vulkaninfo --summary | grep -E "(deviceName|deviceType)" || log_warning "未检测到 Vulkan 设备，请检查 GPU 驱动"
else
    log_warning "vulkaninfo 命令未找到，继续安装 llama.cpp..."
fi

# ============================================
# 步骤 4: 编译 llama.cpp
# ============================================
log_info "步骤 4/5: 克隆并编译 llama.cpp..."

cd ~

# 如果已存在 llama.cpp 目录，跳过克隆
if [ ! -d "llama.cpp" ]; then
    log_info "克隆 llama.cpp 仓库..."
    git clone https://github.com/ggml-org/llama.cpp.git
else
    log_warning "llama.cpp 目录已存在，跳过克隆"
    cd llama.cpp
    git pull
fi

cd llama.cpp

# 如果 build 目录不存在，创建并编译
if [ ! -d "build" ]; then
    mkdir -p build
    cd build

    log_info "配置 CMake (启用 Vulkan 后端)..."
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN=ON \
        -DGGML_NATIVE=ON \
        -DCMAKE_C_FLAGS="-march=native -O3 -ffast-math" \
        -DCMAKE_CXX_FLAGS="-march=native -O3 -ffast-math" \
        -GNinja

    log_info "开始编译 (这可能需要 10-30 分钟)..."
    ninja -j$(nproc)
else
    log_warning "llama.cpp 已编译过，如需重新编译请删除 build 目录"
fi

log_success "llama.cpp 编译完成"

log_success "llama.cpp 编译完成"

log_success "安装完成！"

# ============================================
# 输出使用指南
# ============================================
echo ""
echo "============================================"
echo "  安装完成！使用指南"
echo "============================================"
echo ""
echo "1. 命令行交互模式:"
echo "   cd ~/llama.cpp/build/bin"
echo "   ./llama-cli -m ~/llama-models/${MODEL_NAME} -p \"你好\" -n 100 -ngl 99"
echo ""
echo "2. 启动 HTTP 服务器模式:"
echo "   cd ~/llama.cpp/build/bin"
echo "   ./llama-server -m ~/llama-models/${MODEL_NAME} -ngl 99 -c 4096 --host 0.0.0.0 --port 8080"
echo ""
echo "3. 访问 API (浏览器或 curl):"
echo "   http://localhost:8080"
echo "   curl http://localhost:8080/v1/chat/completions \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"model\": \"default\", \"messages\": [{\"role\": \"user\", \"content\": \"你好\"}]}'"
echo ""
echo "============================================"
echo "  提示"
echo "============================================"
echo ""
echo "- -ngl 99 : 尽可能多的层加载到 GPU (根据显存调整)"
echo "- -c 4096 : 上下文长度 (根据显存调整)"
echo "- 如需下载更大模型，可访问 https://huggingface.co/models?library=gguf"
echo ""
echo "注意: 配置完成后需要重新登录或运行 'source ~/.profile' 使环境变量生效"
echo ""
