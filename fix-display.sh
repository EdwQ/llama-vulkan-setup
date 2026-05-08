#!/bin/bash
# fix-display.sh - 修复 MI50 导致的显示问题
# 紧急恢复脚本

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    MI50 显示问题修复工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检测 GPU 类型
echo "🔍 检测系统中的 GPU 设备..."
echo ""

# 列出所有 PCI 设备中的 GPU
lspci | grep -i vga || echo "未找到 VGA 设备"
lspci | grep -i display || echo "未找到 Display 设备"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查是否有 AMD 集成显卡或其他显示设备
if lspci | grep -i "AMD Radeon" > /dev/null 2>&1; then
    echo "✅ 检测到 AMD 集成显卡（负责显示输出）"
    echo "   这应该是你的主显示设备"
    DISPLAY_GPU="AMD Radeon"
elif lspci | grep -i "NVIDIA" > /dev/null 2>&1; then
    echo "✅ 检测到 NVIDIA 显卡（负责显示输出）"
    DISPLAY_GPU="NVIDIA"
else
    echo "⚠️  未检测到标准显示 GPU"
fi

# 检查 MI50
if lspci | grep -i "MI50" > /dev/null 2>&1; then
    echo "⚠️  检测到 AMD MI50（计算卡，无视频输出）"
    COMPUTE_GPU="MI50"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 问题原因分析："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "MI50 是纯计算卡，没有视频输出接口！"
echo "如果显示输出被设置到 MI50，屏幕将黑屏。"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 修复选项："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "[1] 恢复默认显示设置（推荐 - 使用集成显卡）"
echo "[2] 设置到 NVIDIA 显卡（如果有）"
echo "[3] 仅禁用 MI50 的显示输出"
echo "[4] 查看当前配置"
echo "[q] 退出"
echo ""

read -p "请选择选项 [1-4 或 q]: " choice

case $choice in
    1)
        echo ""
        echo "🔧 恢复默认显示设置..."
        
        # 移除 MI50 相关的显示配置
        echo "  移除 MI50 显示配置..."
        sudo sed -i '/HSA_OVERRIDE_GFX_VERSION/d' /etc/profile.d/rocm.sh 2>/dev/null || true
        sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.zshrc 2>/dev/null || true
        sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.bashrc 2>/dev/null || true
        
        # 移除可能设置的 AMD 设备索引
        sudo sed -i '/amdgpu\.cs_enable/d' /etc/modprobe.d/* 2>/dev/null || true
        
        echo "  ✅ 已移除 MI50 显示配置"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ 修复完成！"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "请重启系统以应用更改："
        echo "  sudo reboot"
        echo ""
        echo "重启后，显示将使用默认 GPU（通常是集成显卡）"
        ;;
    
    2)
        echo ""
        echo "🔧 设置 NVIDIA 显卡为显示设备..."
        
        # 首先移除 MI50 配置
        sudo sed -i '/HSA_OVERRIDE_GFX_VERSION/d' /etc/profile.d/rocm.sh 2>/dev/null || true
        sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.zshrc 2>/dev/null || true
        sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.bashrc 2>/dev/null || true
        sudo sed -i '/ROCM_VISIBLE_DEVICES/d' ~/.zshrc 2>/dev/null || true
        
        # 检查是否有 NVIDIA 显卡
        if lspci | grep -i "NVIDIA" > /dev/null 2>&1; then
            echo "  ✅ 已确认 NVIDIA 显卡存在"
            echo "  ✅ 已移除 MI50 显示配置"
            echo "  ✅ 系统将使用 NVIDIA 显卡作为显示设备"
        else
            echo "  ⚠️  未检测到 NVIDIA 显卡"
            echo "  系统将使用默认 GPU（通常是集成显卡）"
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ 修复完成！"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "请重启系统："
        echo "  sudo reboot"
        ;;
    
    3)
        echo ""
        echo "🔧 禁用 MI50 显示输出..."
        
        # 移除 MI50 相关配置
        sudo sed -i '/HSA_OVERRIDE_GFX_VERSION/d' /etc/profile.d/rocm.sh 2>/dev/null || true
        sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.zshrc 2>/dev/null || true
        sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.bashrc 2>/dev/null || true
        sudo sed -i '/ROCM_VISIBLE_DEVICES/d' ~/.zshrc 2>/dev/null || true
        
        echo "  ✅ 已禁用 MI50 显示相关配置"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ 修复完成！"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "请重启系统："
        echo "  sudo reboot"
        echo ""
        echo "系统会自动使用默认 GPU（集成显卡或 NVIDIA）作为显示设备"
        ;;
    
    4)
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 当前配置："
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        echo ""
        echo "ROCM 配置 (/etc/profile.d/rocm.sh):"
        cat /etc/profile.d/rocm.sh 2>/dev/null || echo "  不存在"
        
        echo ""
        echo "Shell 配置 (~/.zshrc):"
        grep -E "(HSA|VULKAN)" ~/.zshrc 2>/dev/null || echo "  无相关配置"
        
        echo ""
        echo "amdgpu 模块配置:"
        cat /etc/modprobe.d/amdgpu.conf 2>/dev/null || echo "  不存在"
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    
    q|Q)
        echo "👋 已退出"
        exit 0
        ;;
    
    *)
        echo "❌ 无效选项"
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 提示："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "MI50 是计算卡，正确的使用方式是："
echo "  1. 使用集成显卡或另一张 GPU 负责显示"
echo "  2. MI50 仅用于计算任务（llama.cpp）"
echo "  3. 运行 llama.cpp 时通过 --device vulkan 指定 MI50"
echo ""
echo "不要将 MI50 设为系统显示设备！"
echo ""
