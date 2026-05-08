#!/bin/bash
# quick-gpu-check.sh - 快速检测 GPU 状态

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    GPU 快速检测工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检测 NVIDIA
echo -e "📍 NVIDIA GPU:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=gpu_name,memory.total --format=csv 2>/dev/null | head -5
else
    echo "  ❌ NVIDIA 驱动未安装或 nvidia-smi 不可用"
fi

echo ""

# 检测 AMD
echo -e "📍 AMD GPU:"
if [ -d "/dev/dri" ]; then
    for card in /dev/dri/card*; do
        if [ -e "$card" ]; then
            echo "  设备：$card"
            cat /sys/class/dri/card*/device/name 2>/dev/null | head -1
            cat /sys/class/dri/card*/device/vendor 2>/dev/null | head -1
        fi
    done
else
    echo "  ❌ 未检测到 AMD GPU 设备"
fi

echo ""

# 检测 Vulkan
echo -e "📍 Vulkan 支持:"
if command -v vulkaninfo &> /dev/null; then
    echo "  ✅ vulkaninfo 可用"
    echo "  GPU 列表:"
    vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -5
else
    echo "  ❌ vulkaninfo 未安装"
    echo "  安装: sudo apt install vulkan-tools"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
