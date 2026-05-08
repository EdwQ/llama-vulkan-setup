#!/bin/bash
#
# llama.cpp 服务器启动脚本
# 用于后台运行 llama.cpp 服务器
#
# 使用方法:
#   ./start-llama-server.sh [模型路径] [上下文长度]
#
# 示例:
#   ./start-llama-server.sh ~/llama-models/Qwen3.6-27B-IQ4_NL.gguf 4096
#

MODEL_PATH="${1:-$HOME/llama-models/Qwen3.6-27B-IQ4_NL.gguf}"
CONTEXT="${2:-4096}"
PORT="${3:-8081}"

echo "============================================"
echo "  llama.cpp 服务器启动"
echo "============================================"
echo ""
echo "模型：$MODEL_PATH"
echo "上下文：$CONTEXT"
echo "端口：$PORT"
echo ""

# 检查模型文件是否存在
if [ ! -f "$MODEL_PATH" ]; then
    echo "错误：模型文件不存在！"
    echo ""
    echo "请先下载模型:"
    echo "  mkdir -p ~/llama-models"
    echo "  cd ~/llama-models"
    echo "  wget 'https://cdn-lfs-cn-1.modelscope.cn/prod/lfs-objects/23/96/58ade790aa63812407ad91f6365d845e689009f70d302a59d65e9eec584e?filename=Qwen3.6-27B-IQ4_NL.gguf&namespace=unsloth&repository=Qwen3.6-27B-GGUF&revision=master&tag=model&auth_key=1778249190-823f5383dfab420a91efff4035d237dd-0-5f08b1700df838f364412c7c8163967d'"
    exit 1
fi

# 检查 llama.cpp 是否编译
if [ ! -f "$HOME/llama.cpp/build/bin/llama-server" ]; then
    echo "错误：llama-server 未找到！"
    echo ""
    echo "请先编译 llama.cpp:"
    echo "  cd ~/llama.cpp"
    echo "  mkdir -p build && cd build"
    echo "  cmake .. -DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON"
    echo "  ninja"
    exit 1
fi

echo "启动服务器..."
echo ""

# 启动服务器（前台模式，按 Ctrl+C 停止）
cd ~/llama.cpp/build/bin

nohup ./llama-server \
  -m "$MODEL_PATH" \
  -ngl 99 \
  -c "$CONTEXT" \
  -b 2048 \
  -ub 2048 \
  --host 0.0.0.0 \
  --port "$PORT" \
  > ~/llama-server.log 2>&1 &

PID=$!
echo "服务器已启动 (PID: $PID)"
echo ""
echo "日志文件：~/llama-server.log"
echo "访问地址：http://localhost:$PORT"
echo ""
echo "停止服务器:"
echo "  kill $PID"
echo "  或: pkill llama-server"
echo ""

# 等待几秒钟检查是否启动成功
sleep 3

if ps -p $PID > /dev/null; then
    echo "✅ 服务器运行正常!"
else
    echo "❌ 服务器启动失败，请查看日志:"
    echo "  tail -f ~/llama-server.log"
fi
