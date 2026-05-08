#!/bin/bash
# llama-vulkan-setup - GPU 检测和交互式选择脚本
# 支持 AMD MI50 和 NVIDIA RTX 3060 双 GPU 配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测 Vulkan 可用的 GPU 列表
detect_vulkan_gpu() {
    echo -e "${BLUE}🔍 检测 Vulkan 可用 GPU...${NC}"
    
    vulkan_gpu_list=()
    vulkan_gpu_count=0
    
    # 尝试使用 vulkaninfo 获取 GPU 信息
    if command -v vulkaninfo &> /dev/null; then
        gpu_index=0
        # 改进解析：使用更稳定的 grep 和 sed 模式
        while IFS= read -r line; do
            if [[ "$line" == *"deviceName"* ]]; then
                # 提取 GPU 名称（去除前导空格和=符号）
                gpu_name=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/.*=[[:space:]]*//')
                if [ -n "$gpu_name" ]; then
                    vulkan_gpu_list[$gpu_index]="$gpu_name"
                    ((gpu_index++))
                    ((vulkan_gpu_count++))
                fi
            fi
        done < <(vulkaninfo --summary 2>/dev/null | grep -i "deviceName")
    fi
    
    # 如果 vulkaninfo 解析失败，尝试其他方法
    if [ $vulkan_gpu_count -eq 0 ]; then
        echo -e "${YELLOW}⚠️  vulkaninfo 未返回 GPU 信息，尝试其他方式检测...${NC}"
        
        # 检测 NVIDIA GPU
        if command -v nvidia-smi &> /dev/null; then
            nvidia_count=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | wc -l)
            if [ $nvidia_count -gt 0 ]; then
                while IFS= read -r gpu_name; do
                    vulkan_gpu_list[$vulkan_gpu_count]="$gpu_name (NVIDIA)"
                    ((vulkan_gpu_count++))
                done < <(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null)
            fi
        fi
        
        # 检测 AMD GPU
        if [ -d "/dev/dri" ]; then
            for card in /dev/dri/card*; do
                if [ -e "$card" ]; then
                    gpu_name=$(cat "$card"/../device/name 2>/dev/null | head -1)
                    if [ -n "$gpu_name" ]; then
                        vulkan_gpu_list[$vulkan_gpu_count]="$gpu_name (AMD)"
                        ((vulkan_gpu_count++))
                    fi
                fi
            done
        fi
        
        # 最后尝试：检查是否有 llvmpipe（软件渲染）
        if [ $vulkan_gpu_count -eq 0 ]; then
            echo -e "${YELLOW}⚠️  未检测到独立 GPU，使用软件渲染（llvmpipe）${NC}"
            vulkan_gpu_list[$vulkan_gpu_count]="llvmpipe (Software Rendering)"
            ((vulkan_gpu_count++))
        fi
    fi
    
    if [ $vulkan_gpu_count -eq 0 ]; then
        echo -e "${RED}❌ 未检测到 Vulkan 设备${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 检测到 $vulkan_gpu_count 个 Vulkan 设备${NC}"
}

# 显示 GPU 信息
show_gpu_info() {
    echo ""
    echo -e "${BLUE}📊 GPU 信息:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for i in "${!vulkan_gpu_list[@]}"; do
        if [[ "${vulkan_gpu_list[$i]}" =~ "MI50" ]] || [[ "${vulkan_gpu_list[$i]}" =~ "gfx906" ]]; then
            echo -e "  [${GREEN}$i${NC}] ${vulkan_gpu_list[$i]} ${GREEN}(AMD MI50 - 推荐大模型加载)${NC}"
        echo "    注意：AMD MI50 使用 Vulkan 后端，确保驱动已正确安装"
        elif [[ "${vulkan_gpu_list[$i]}" =~ "RTX 3060" ]] || [[ "${vulkan_gpu_list[$i]}" =~ "NVIDIA" ]]; then
            echo -e "  [${YELLOW}$i${NC}] ${vulkan_gpu_list[$i]} ${YELLOW}(RTX 3060 - 推荐快速推理)${NC}"
        else
            echo -e "  [${BLUE}$i${NC}] ${vulkan_gpu_list[$i]}"
        fi
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 交互式选择 GPU
select_gpu() {
    echo -e "${BLUE}🎮 请选择要使用的 GPU:${NC}"
    echo ""
    
    # 显示 GPU 列表
    for i in "${!vulkan_gpu_list[@]}"; do
        echo "  [$i] ${vulkan_gpu_list[$i]}"
    done
    
    echo ""
    
    # 添加退出选项
    echo "  [q] 退出"
    echo ""
    
    # 获取用户输入
    while true; do
        read -p "请输入选项 [0-$((${#vulkan_gpu_list[@]} - 1)) 或 q]: " choice
        
        # 检查是否退出
        if [[ "$choice" =~ ^[qQ]$ ]]; then
            echo -e "${YELLOW}👋 已退出${NC}"
            exit 0
        fi
        
        # 验证输入
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "${#vulkan_gpu_list[@]}" ]; then
            selected_gpu_index=$choice
            selected_gpu_name="${vulkan_gpu_list[$choice]}"
            break
        else
            echo -e "${RED}❌ 无效选项，请重新输入${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ 已选择: $selected_gpu_name${NC}"
}

# 设置环境变量
setup_gpu_env() {
    echo ""
    echo -e "${BLUE}⚙️  设置 GPU 环境变量...${NC}"
    
    # 根据 GPU 类型设置不同的环境变量
    if [[ "$selected_gpu_name" =~ "AMD" ]] || [[ "$selected_gpu_name" =~ "MI50" ]]; then
        echo -e "${GREEN}  检测到 AMD GPU，设置 ROCM/Vulkan 环境变量...${NC}"
        export HSA_OVERRIDE_GFX_VERSION="9.0.6"
        export ROCM_VISIBLE_DEVICES="$selected_gpu_index"
        export VULKAN_DEVICE_INDEX="$selected_gpu_index"
        echo "  export HSA_OVERRIDE_GFX_VERSION=\"9.0.6\"" >> ~/.zshrc
        echo "  export VULKAN_DEVICE_INDEX=\"$selected_gpu_index\"" >> ~/.zshrc
    elif [[ "$selected_gpu_name" =~ "NVIDIA" ]] || [[ "$selected_gpu_name" =~ "RTX" ]]; then
        echo -e "${GREEN}  检测到 NVIDIA GPU，设置 CUDA/Vulkan 环境变量...${NC}"
        export CUDA_VISIBLE_DEVICES="$selected_gpu_index"
        export VULKAN_DEVICE_INDEX="$selected_gpu_index"
        echo "  export CUDA_VISIBLE_DEVICES=\"$selected_gpu_index\"" >> ~/.zshrc
        echo "  export VULKAN_DEVICE_INDEX=\"$selected_gpu_index\"" >> ~/.zshrc
    fi
    
    echo -e "${GREEN}✅ GPU 环境变量已设置${NC}"
}

# 生成 llama.cpp 运行参数
generate_llama_params() {
    echo ""
    echo -e "${BLUE}📝 生成 llama.cpp 运行参数...${NC}"
    
    # 根据选择的 GPU 类型生成参数
    if [[ "$selected_gpu_name" =~ "AMD" ]] || [[ "$selected_gpu_name" =~ "MI50" ]]; then
        GPU_PARAMS="-ngl 99 -fa --device vulkan --gpu $selected_gpu_index"
        echo -e "${YELLOW}⚠️  AMD MI50 提示:${NC}"
        echo "  - 使用gfx906架构，确保Vulkan驱动已正确安装"
        echo "  - 如果遇到加载问题，尝试降低层数 (-ngl 50)"
    elif [[ "$selected_gpu_name" =~ "NVIDIA" ]] || [[ "$selected_gpu_name" =~ "RTX" ]]; then
        GPU_PARAMS="-ngl 99 -fa --device cuda --gpu $selected_gpu_index"
        echo -e "${GREEN}✅ NVIDIA RTX 3060 配置完成${NC}"
        echo "  - 使用 CUDA 后端，性能较好"
    else
        GPU_PARAMS="-ngl 99 -fa --device vulkan --gpu $selected_gpu_index"
    fi
    
    echo ""
    echo -e "${BLUE}🔧 推荐的 llama-cli 命令:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  llama-cli -m <模型路径> $GPU_PARAMS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 主函数
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}    llama-vulkan-setup 双 GPU 配置工具${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 检测 GPU
    detect_vulkan_gpu
    
    if [ $vulkan_gpu_count -eq 0 ]; then
        echo -e "${RED}❌ 未检测到 Vulkan 设备${NC}"
        echo ""
        echo "请确保:"
        echo "  1. 已安装 Vulkan 运行时"
        echo "  2. AMD/ NVIDIA 驱动程序已正确安装"
        echo "  3. 安装了 vulkan-tools (vulkaninfo)"
        echo ""
        echo "安装 Vulkan 工具:"
        echo "  sudo apt install vulkan-tools  # Ubuntu/Debian"
        echo "  brew install vulkan-headers    # macOS"
        echo ""
        exit 1
    fi
    
    # 显示 GPU 信息
    show_gpu_info
    
    # 交互式选择
    select_gpu
    
    # 设置环境变量
    setup_gpu_env
    
    # 生成运行参数
    generate_llama_params
    
    echo -e "${GREEN}✅ 配置完成！${NC}"
    echo ""
    echo "提示: 环境变量已添加到 ~/.zshrc，重启终端后生效"
    echo "或者在当前终端执行: source ~/.zshrc"
    echo ""
}

# 运行主函数
main
