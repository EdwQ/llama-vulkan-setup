#!/bin/bash
#
# Open WebUI + llama.cpp 一键部署脚本
# 提供类似 ChatGPT 的 Web 管理界面
#
# 使用方法:
#   chmod +x setup-openwebui.sh
#   ./setup-openwebui.sh
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "============================================"
echo "  Open WebUI + llama.cpp 一键部署"
echo "============================================"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    log_warning "Docker 未安装，正在安装..."
    
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    
    log_success "Docker 安装完成"
    log_info "请重新登录或运行 'newgrp docker' 使 Docker 组生效"
fi

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    log_warning "docker-compose 未安装，尝试安装..."
    sudo apt install -y docker-compose || true
fi

# 创建配置目录
mkdir -p ~/open-webui
cd ~/open-webui

# 创建 docker-compose.yml
log_info "创建 docker-compose.yml..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama:/root/.ollama
    ports:
      - 11434:11434
    restart: always
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: openwebui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui:/app/backend/data
    ports:
      - 3000:8080
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_AUTH=false
    extra_hosts:
      - host.docker.internal:host-gateway
    restart: always
    depends_on:
      - ollama

volumes:
  ollama:
  open-webui:
EOF

log_success "docker-compose.yml 创建完成"

# 创建 llama.cpp 启动脚本
log_info "创建 llama.cpp 启动脚本..."

cat > start-llama-server.sh << 'EOF'
#!/bin/bash
# llama.cpp 服务器启动脚本

MODEL_PATH="${1:-$HOME/llama-models/Qwen3.6-27B-IQ4_NL.gguf}"
CONTEXT="${2:-4096}"

echo "启动 llama.cpp 服务器..."
echo "模型：$MODEL_PATH"
echo "上下文：$CONTEXT"

cd ~/llama.cpp/build/bin

./llama-server \
  -m "$MODEL_PATH" \
  -ngl 99 \
  -c "$CONTEXT" \
  -b 2048 \
  -ub 2048 \
  --host 0.0.0.0 \
  --port 8081
EOF

chmod +x start-llama-server.sh

# 创建 Open WebUI 启动脚本
log_info "创建 Open WebUI 启动脚本..."

cat > start-openwebui.sh << 'EOF'
#!/bin/bash
# Open WebUI 启动脚本

echo "启动 Open WebUI..."
echo ""
echo "访问地址：http://localhost:3000"
echo ""

docker-compose up -d

echo ""
log_success "Open WebUI 已启动!"
echo ""
echo "查看日志：docker-compose logs -f"
echo "停止服务：docker-compose down"
EOF

chmod +x start-openwebui.sh

# 创建 llama.cpp 连接配置脚本
log_info "创建 llama.cpp 连接配置..."

cat > configure-llamacpp.sh << 'EOF'
#!/bin/bash
# 配置 llama.cpp 与 Open WebUI 连接

echo "============================================"
echo "  llama.cpp + Open WebUI 配置指南"
echo "============================================"
echo ""
echo "方案 A: 使用 llama.cpp 作为后端"
echo ""
echo "1. 启动 llama.cpp 服务器:"
echo "   ./start-llama-server.sh"
echo ""
echo "2. 在 Open WebUI 中配置:"
echo "   - 访问 http://localhost:3000"
echo "   - 进入设置 → 连接"
echo "   - 添加新连接:"
echo "     名称：llama.cpp"
echo "     基础 URL: http://host.docker.internal:8081"
echo "     类型：OpenAI 兼容"
echo ""
echo "方案 B: 使用 Ollama 作为后端（推荐）"
echo ""
echo "1. 安装 Ollama:"
echo "   curl -fsSL https://ollama.com/install.sh | sh"
echo ""
echo "2. 拉取模型:"
echo "   ollama pull qwen2.5:7b"
echo ""
echo "3. Open WebUI 会自动连接 Ollama"
echo ""
echo "============================================"
EOF

chmod +x configure-llamacpp.sh

# 创建 README
log_info "创建 README..."

cat > README.md << 'EOF'
# Open WebUI + llama.cpp 部署指南

## 📦 目录结构

- `docker-compose.yml` - Docker Compose 配置文件
- `start-llama-server.sh` - llama.cpp 服务器启动脚本
- `start-openwebui.sh` - Open WebUI 启动脚本
- `configure-llamacpp.sh` - 连接配置指南

## 🚀 快速开始

### 方式 1: 使用 Open WebUI + Ollama（推荐）

```bash
# 1. 启动 Open WebUI
./start-openwebui.sh

# 2. 浏览器访问
http://localhost:3000
```

### 方式 2: 使用 llama.cpp 作为后端

```bash
# 1. 启动 llama.cpp 服务器
./start-llama-server.sh

# 2. 启动 Open WebUI
./start-openwebui.sh

# 3. 在 Open WebUI 中配置连接
./configure-llamacpp.sh
```

## 📊 功能特性

- ✅ 类似 ChatGPT 的现代化界面
- ✅ 支持多模型管理
- ✅ 对话历史记录
- ✅ 支持文件上传
- ✅ 用户管理
- ✅ API 密钥管理
- ✅ 支持 RAG（知识库）

## 🔧 常用命令

```bash
# 查看所有服务状态
docker-compose ps

# 查看日志
docker-compose logs -f open-webui

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 更新 Open WebUI
docker-compose pull
docker-compose up -d
```

## 🌐 访问地址

- **Open WebUI**: http://localhost:3000
- **llama.cpp API**: http://localhost:8081
- **Ollama API**: http://localhost:11434

## 📝 注意事项

1. 首次启动需要下载镜像，可能需要几分钟
2. 确保 Docker 服务正在运行
3. 如需局域网访问，修改 `--host 0.0.0.0` 参数
EOF

log_success "所有文件创建完成!"

# 输出使用指南
echo ""
echo "============================================"
echo "  安装完成！使用指南"
echo "============================================"
echo ""
echo "1. 启动 Open WebUI:"
echo "   cd ~/open-webui"
echo "   ./start-openwebui.sh"
echo ""
echo "2. 浏览器访问:"
echo "   http://localhost:3000"
echo ""
echo "3. 使用 llama.cpp 作为后端:"
echo "   ./start-llama-server.sh  # 在另一个终端"
echo "   # 然后在 Open WebUI 中配置连接"
echo ""
echo "============================================"
echo "  文件位置"
echo "============================================"
echo ""
echo "配置文件：~/open-webui/"
echo "  - docker-compose.yml"
echo "  - start-llama-server.sh"
echo "  - start-openwebui.sh"
echo "  - configure-llamacpp.sh"
echo "  - README.md"
echo ""
echo "============================================"
