#!/bin/bash
# run-llm.sh - 交互式模型选择和运行脚本
# 自动检测模型和 GPU，简化 llama.cpp 使用

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测 GPU 类型和后端
detect_gpu_backend() {
    BACKEND=""
    GPU_INDEX=0
    
    if command -v nvidia-smi &> /dev/null && nvidia-smi > /dev/null 2>&1; then
        BACKEND="cuda"
        log_info "检测到 NVIDIA GPU，使用 CUDA 后端"
    elif command -v vulkaninfo &> /dev/null; then
        # 检测可用 Vulkan 设备
        vulkan_count=$(vulkaninfo --summary 2>/dev/null | grep -c "deviceName" || echo "0")
        
        if [ "$vulkan_count" -gt 0 ]; then
            BACKEND="vulkan"
            log_info "检测到 Vulkan 设备，使用 Vulkan 后端"
            
            # 显示 GPU 列表
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Vulkan 可用 GPU 列表:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            vulkaninfo --summary 2>/dev/null | grep "deviceName" | nl -w2 -s": "
            
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            # 询问使用哪个 GPU
            read -p "选择 GPU 索引 (默认 0): " gpu_choice
            if [ -n "$gpu_choice" ] && [ "$gpu_choice" -ge 0 ]; then
                GPU_INDEX=$gpu_choice
            fi
        fi
    fi
    
    if [ -z "$BACKEND" ]; then
        BACKEND="cpu"
        log_warning "未检测到 GPU，将使用 CPU 后端（速度较慢）"
    fi
}

# 检测模型文件夹
detect_models() {
    MODELS_DIR="$1"
    
    if [ ! -d "$MODELS_DIR" ]; then
        log_warning "模型文件夹不存在：$MODELS_DIR"
        mkdir -p "$MODELS_DIR"
        return 1
    fi
    
    # 查找所有 GGUF 文件
    mapfile -t MODEL_FILES < <(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)
    
    if [ ${#MODEL_FILES[@]} -eq 0 ]; then
        log_warning "未找到 GGUF 模型文件"
        return 1
    fi
    
    return 0
}

# 显示模型信息
show_model_info() {
    local model_file="$1"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 模型信息:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "文件: $(basename "$model_file")"
    echo "路径: $model_file"
    echo "大小: $(ls -lh "$model_file" | awk '{print $5}')"
    echo ""
    
    # 尝试获取模型信息（如果 llama-cli 可用）
    if command -v llama-cli &> /dev/null; then
        echo "尝试获取模型详情..."
        llama-cli -m "$model_file" -n 0 2>&1 | head -20 || true
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 配置运行参数
configure_params() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  配置运行参数:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 生成 token 数
    read -p "生成 token 数量 (默认 512): " n_predict
    N_PREDICT=${n_predict:-512}
    
    # 温度参数
    echo ""
    echo "温度参数 (0.1=精确, 1.0=随机):"
    read -p "默认 0.7: " temperature
    TEMPERATURE=${temperature:-0.7}
    
    # 系统提示
    echo ""
    read -p "系统提示词 (默认'你是一个有用的助手'): " system_prompt
    SYSTEM_PROMPT=${system_prompt:-"你是一个有用的助手"}
    
    # 上下文大小
    echo ""
    read -p "上下文大小 (默认 2048): " n_ctx
    N_CTX=${n_ctx:-2048}
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 运行 llama.cpp
run_llama() {
    local model_file="$1"
    local gpu_index="$2"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 启动 llama.cpp..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "模型: $(basename "$model_file")"
    echo "后端: $BACKEND"
    echo "GPU 索引：$gpu_index"
    echo "生成 token: $N_PREDICT"
    echo "温度：$TEMPERATURE"
    echo "上下文：$N_CTX"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 构建命令
    if [ "$BACKEND" = "cuda" ]; then
        CMD="llama-cli -m \"$model_file\" -ngl 99 -fa --device cuda --gpu $gpu_index -n $N_PREDICT -t 4 -b $N_CTX --temp $TEMPERATURE -i -cnv -p \"$SYSTEM_PROMPT\""
    elif [ "$BACKEND" = "vulkan" ]; then
        CMD="llama-cli -m \"$model_file\" -ngl 99 -fa --device vulkan --gpu $gpu_index -n $N_PREDICT -t 4 -b $N_CTX --temp $TEMPERATURE -i -cnv -p \"$SYSTEM_PROMPT\""
    else
        CMD="llama-cli -m \"$model_file\" -n $N_PREDICT -t 4 -b $N_CTX --temp $TEMPERATURE -i -cnv -p \"$SYSTEM_PROMPT\""
    fi
    
    echo "命令:"
    echo "$CMD"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    read -p "按 Enter 开始，或输入 q 退出..." confirm
    
    if [[ "$confirm" =~ ^[qQ]$ ]]; then
        echo "👋 已退出"
        exit 0
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "开始对话（输入 /quit 退出）:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 执行命令
    eval $CMD
}

# 主菜单
show_menu() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}    llama.cpp 模型运行工具${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "[1] 运行模型（交互式聊天）"
    echo "[2] 查看已下载模型列表"
    echo "[3] 下载模型指南"
    echo "[4] 系统信息"
    echo "[q] 退出"
    echo ""
}

# 显示下载指南
show_download_guide() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📥 模型下载指南"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "推荐模型下载位置:"
    echo ""
    echo "国际用户:"
    echo "  https://huggingface.co/models?search=gguf"
    echo ""
    echo "国内用户（推荐）:"
    echo "  https://modelscope.cn/models?search=gguf"
    echo ""
    echo "热门模型:"
    echo "  - Qwen2.5-7B: https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF"
    echo "  - Llama-3.1-8B: https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct-GGUF"
    echo "  - Gemma-7B: https://huggingface.co/google/gemma-7b-it-GGUF"
    echo ""
    echo "下载命令示例:"
    echo ""
    echo "【使用 huggingface-cli】"
    echo "  pip install huggingface-hub"
    echo "  huggingface-cli download Qwen/Qwen2.5-7B-Instruct-GGUF qwen2.5-7b-instruct-q4_k_m.gguf"
    echo ""
    echo "【使用 modelscope-cli（国内推荐）】"
    echo "  pip install modelscope"
    echo "  modelscope download --model Qwen/Qwen2.5-7B-Instruct-GGUF --revision master qwen2.5-7b-instruct-q4_k_m.gguf"
    echo ""
    echo "【直接 wget】"
    echo "  wget https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf"
    echo ""
    echo "下载后移动到 ~/models/ 目录:"
    echo "  mkdir -p ~/models"
    echo "  mv ~/Downloads/*.gguf ~/models/"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 显示系统信息
show_system_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 系统信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "llama.cpp 状态:"
    if command -v llama-cli &> /dev/null; then
        echo "  ✅ 已安装"
        llama-cli --version 2>&1 | head -1 || true
    else
        echo "  ❌ 未安装"
    fi
    
    echo ""
    echo "GPU 状态:"
    if command -v nvidia-smi &> /dev/null; then
        echo "  NVIDIA GPU: 已检测"
        nvidia-smi --query-gpu=gpu_name,memory.total --format=csv,noheader 2>/dev/null | head -1 || true
    fi
    
    if command -v vulkaninfo &> /dev/null; then
        echo "  Vulkan: 已安装"
        vulkaninfo --summary 2>/dev/null | grep "deviceName" || true
    fi
    
    echo ""
    echo "模型文件夹:"
    if [ -d "$MODELS_DIR" ]; then
        model_count=$(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | wc -l)
        echo "  路径：$MODELS_DIR"
        echo "  模型数量：$model_count"
    else
        echo "  未创建（运行脚本会自动创建）"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 主函数
main() {
    MODELS_DIR="$HOME/models"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}    llama.cpp 模型运行工具${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 检测 GPU
    detect_gpu_backend
    
    # 检测模型
    if ! detect_models "$MODELS_DIR"; then
        log_info "正在创建模型文件夹..."
        mkdir -p "$MODELS_DIR"
        log_warning "模型文件夹为空，请先下载模型"
        show_download_guide
        exit 0
    fi
    
    log_success "找到 ${#MODEL_FILES[@]} 个模型"
    
    # 主循环
    while true; do
        show_menu
        read -p "请选择 [1-4 或 q]: " choice
        
        case $choice in
            1)
                # 运行模型
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📋 选择模型:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                # 显示模型列表
                for i in "${!MODEL_FILES[@]}"; do
                    echo "  [$i] $(basename "${MODEL_FILES[$i]}")"
                done
                
                echo "  [b] 返回主菜单"
                echo ""
                
                read -p "选择模型 [0-$((${#MODEL_FILES[@]} - 1))] 或 b: " model_choice
                
                if [[ "$model_choice" =~ ^[bB]$ ]]; then
                    continue
                fi
                
                if [[ "$model_choice" =~ ^[0-9]+$ ]] && [ "$model_choice" -lt "${#MODEL_FILES[@]}" ]; then
                    selected_model="${MODEL_FILES[$model_choice]}"
                    
                    # 显示模型信息
                    show_model_info "$selected_model"
                    
                    # 配置参数
                    configure_params
                    
                    # 运行
                    run_llama "$selected_model" "$GPU_INDEX"
                else
                    log_error "无效选择"
                fi
                ;;
            
            2)
                # 查看模型列表
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📦 已下载模型:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                for i in "${!MODEL_FILES[@]}"; do
                    echo ""
                    echo "[$i] $(basename "${MODEL_FILES[$i]}")"
                    echo "    路径: ${MODEL_FILES[$i]}"
                    echo "    大小: $(ls -lh "${MODEL_FILES[$i]}" | awk '{print $5}')"
                done
                
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                read -p "按 Enter 返回..."
                ;;
            
            3)
                show_download_guide
                read -p "按 Enter 返回..."
                ;;
            
            4)
                show_system_info
                read -p "按 Enter 返回..."
                ;;
            
            q|Q)
                echo ""
                echo "👋 退出"
                exit 0
                ;;
            
            *)
                log_error "无效选项"
                ;;
        esac
    done
}

# 运行主函数
main
