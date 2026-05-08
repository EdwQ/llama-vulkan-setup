# Open WebUI + llama.cpp 完整部署指南

> 提供类似 ChatGPT 的 Web 管理界面，支持后台运行和局域网访问

## 📦 项目文件

| 文件 | 说明 |
|------|------|
| `setup-openwebui.sh` | Open WebUI 一键部署脚本 |
| `start-llama-server.sh` | llama.cpp 服务器启动脚本 |
| `docker-compose-openwebui.yml` | Docker Compose 配置文件 |
| `README-OPENWEBUI.md` | 本文档 |

---

## 🚀 快速开始

### 方案 1: 使用 llama.cpp 自带 WebUI（最简单）

```bash
# 启动 llama.cpp 服务器
./start-llama-server.sh ~/llama-models/Qwen3.6-27B-IQ4_NL.gguf 4096

# 浏览器访问
http://localhost:8081
```

**特点**：
- ✅ 无需额外安装
- ✅ 自带聊天界面
- ⚠️ 功能较简单

---

### 方案 2: 使用 Open WebUI（推荐）⭐

#### 步骤 1: 安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

#### 步骤 2: 启动 Open WebUI

```bash
cd ~/openclaw/workspace
docker-compose -f docker-compose-openwebui.yml up -d
```

#### 步骤 3: 启动 llama.cpp 服务器

```bash
./start-llama-server.sh ~/llama-models/Qwen3.6-27B-IQ4_NL.gguf 4096
```

#### 步骤 4: 浏览器访问

```
http://localhost:3000
```

---

## 📊 Open WebUI 功能

### 核心特性

- ✅ **现代化界面**：类似 ChatGPT 的聊天界面
- ✅ **多模型管理**：支持同时管理多个模型
- ✅ **历史记录**：自动保存对话历史
- ✅ **文件上传**：支持上传文档进行问答
- ✅ **知识库/RAG**：支持知识库检索增强
- ✅ **用户管理**：支持多用户和权限控制
- ✅ **API 管理**：内置 API 密钥管理
- ✅ **功能插件**：支持代码执行、联网搜索等

### 界面截图功能

1. **聊天界面**：实时对话，支持 Markdown 渲染
2. **模型管理**：查看和管理已加载的模型
3. **设置页面**：配置参数、API 密钥、系统设置
4. **知识库**：上传文档并用于问答
5. **用户管理**：管理用户和权限

---

## 🔧 常用命令

### 服务管理

```bash
# 查看所有服务状态
docker-compose -f docker-compose-openwebui.yml ps

# 查看日志
docker-compose -f docker-compose-openwebui.yml logs -f open-webui

# 停止服务
docker-compose -f docker-compose-openwebui.yml down

# 重启服务
docker-compose -f docker-compose-openwebui.yml restart

# 更新镜像
docker-compose -f docker-compose-openwebui.yml pull
docker-compose -f docker-compose-openwebui.yml up -d
```

### llama.cpp 服务器

```bash
# 启动服务器
./start-llama-server.sh ~/llama-models/Qwen3.6-27B-IQ4_NL.gguf 4096

# 查看日志
tail -f ~/llama-server.log

# 停止服务器
pkill llama-server
```

---

## 🌐 局域网访问

### 1. 获取本机 IP

```bash
# macOS/Linux
ipconfig getifaddr en0  # macOS
hostname -I             # Linux

# 或使用
ifconfig | grep "inet "
```

### 2. 修改启动参数

```bash
# llama.cpp 服务器
./start-llama-server.sh ~/llama-models/Qwen3.6-27B-IQ4_NL.gguf 4096 8081
# 确保 --host 0.0.0.0 已设置（脚本默认已设置）

# Open WebUI
# 修改 docker-compose-openwebui.yml 中的 ports
ports:
  - "3000:8080"  # 默认已设置
```

### 3. 其他设备访问

```
http://<本机 IP>:3000
```

---

## 📝 配置参数说明

### llama-server 参数

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `-m` | 模型路径 | 模型文件路径 |
| `-ngl` | GPU 层数 | `99` (尽可能多) |
| `-c` | 上下文长度 | `4096` 或 `8192` |
| `-b` | 批处理大小 | `2048` |
| `-ub` | 统一批处理 | `2048` |
| `--host` | 监听地址 | `0.0.0.0` (局域网) |
| `--port` | 端口 | `8081` |

### Open WebUI 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `OLLAMA_BASE_URL` | llama.cpp 地址 | `http://host.docker.internal:8081` |
| `WEBUI_AUTH` | 是否启用认证 | `false` |
| `ENABLE_WEBUI_AUTH` | 允许外部 API | `false` |

---

## 🔐 安全性建议

### 生产环境配置

1. **启用认证**：
```yaml
environment:
  - WEBUI_AUTH=true
  - DEFAULT_USER_EMAIL=your@email.com
  - DEFAULT_USER_PASSWORD=yourpassword
```

2. **使用 HTTPS**：
```bash
# 使用 Caddy 或 Nginx 反向代理
```

3. **限制网络访问**：
```bash
# 仅允许特定 IP 访问
# 修改 --host 参数或使用防火墙
```

---

## 🛠️ 故障排查

### 问题 1: Open WebUI 无法连接 llama.cpp

**症状**：Open WebUI 显示"模型不可用"

**解决方案**：
```bash
# 1. 确认 llama.cpp 服务器正在运行
ps aux | grep llama-server

# 2. 检查端口
curl http://localhost:8081/health

# 3. 检查 Docker 网络配置
docker-compose -f docker-compose-openwebui.yml config
```

### 问题 2: Docker 权限问题

**症状**：Permission denied

**解决方案**：
```bash
# 重新加入 Docker 组
sudo usermod -aG docker $USER
newgrp docker

# 或重启系统
```

### 问题 3: 显存不足

**症状**：服务器启动失败或运行缓慢

**解决方案**：
```bash
# 减小上下文长度
./start-llama-server.sh ~/llama-models/Qwen3.6-27B-IQ4_NL.gguf 2048

# 或使用更小的模型
# 例如：Qwen2.5-7B
```

---

## 📚 扩展阅读

- [llama.cpp 官方文档](https://github.com/ggml-org/llama.cpp)
- [Open WebUI 官方文档](https://docs.openwebui.com/)
- [llama.cpp WebUI 指南](https://github.com/ggml-org/llama.cpp/discussions/16938)

---

## 🎯 推荐工作流程

1. **开发/测试**：使用 llama.cpp 自带 WebUI（端口 8081）
2. **日常使用**：使用 Open WebUI（端口 3000）
3. **生产环境**：Open WebUI + 认证 + HTTPS

---

**最后更新**: 2026-05-08
