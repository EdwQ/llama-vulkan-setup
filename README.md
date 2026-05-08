# llama-vulkan-setup - 双 GPU 配置工具

用于在 AMD MI50 + NVIDIA RTX 3060 双 GPU 系统上配置 Vulkan 和 llama.cpp 的工具集。

## 📁 脚本说明

### 1. `llama-vulkan-full-setup.sh` - 一键安装脚本
**功能：** 自动检测系统类型并安装所有必要的组件
- ✅ 自动识别操作系统 (Ubuntu/Debian/CentOS/macOS)
- ✅ 安装 Vulkan 运行时和工具
- ✅ 安装 GPU 驱动 (NVIDIA/AMD)
- ✅ 配置 AMD MI50 gfx906 特殊支持
- ✅ 编译安装 llama.cpp (启用 GPU 后端)
- ✅ 验证安装状态

**使用方法：**
```bash
# Linux (需要 sudo 权限)
sudo ~/llama-vulkan-setup/llama-vulkan-full-setup.sh

# macOS (需要 Homebrew)
~/llama-vulkan-setup/llama-vulkan-full-setup.sh
```

### 2. `gpu-selector.sh` - GPU 选择器
**功能：** 交互式选择要使用的 GPU
- 🔍 自动检测 Vulkan 可用 GPU
- 📊 显示 GPU 详细信息
- 🎮 交互式菜单选择
- ⚙️ 自动设置环境变量
- 📝 生成 llama.cpp 运行参数

**使用方法：**
```bash
~/llama-vulkan-setup/gpu-selector.sh
```

### 3. `quick-gpu-check.sh` - 快速检测
**功能：** 快速查看 GPU 状态
- 检查 NVIDIA/AMD GPU 是否可用
- 检查 Vulkan 支持情况
- 显示 GPU 显存信息

**使用方法：**
```bash
~/llama-vulkan-setup/quick-gpu-check.sh
```

## 🚀 快速开始

### 步骤 1: 安装依赖
```bash
sudo ~/llama-vulkan-setup/llama-vulkan-full-setup.sh
```

### 步骤 2: 重启系统
```bash
sudo reboot
```

### 步骤 3: 选择 GPU
```bash
~/llama-vulkan-setup/gpu-selector.sh
```

### 步骤 4: 运行 llama.cpp
```bash
llama-cli -m /path/to/model.gguf -ngl 99 -fa --device vulkan --gpu 0
```

## 🎯 GPU 选择建议

### AMD MI50 (gfx906)
- **优势：** 16GB 大显存，适合加载大模型
- **推荐场景：** 运行 7B/13B/30B 等大参数模型
- **注意：** 需要设置 `HSA_OVERRIDE_GFX_VERSION=9.0.6`

### NVIDIA RTX 3060 (12GB)
- **优势：** CUDA 生态完善，推理速度快
- **推荐场景：** 快速推理、小模型 (7B 以下)
- **注意：** 显存较小，大模型可能放不下

## 🔧 手动配置示例

### 仅使用 RTX 3060
```bash
export CUDA_VISIBLE_DEVICES=0
export VULKAN_DEVICE_INDEX=0
llama-cli -m model.gguf -ngl 99 -fa --device cuda
```

### 仅使用 MI50
```bash
export HSA_OVERRIDE_GFX_VERSION=9.0.6
export VULKAN_DEVICE_INDEX=1
llama-cli -m model.gguf -ngl 99 -fa --device vulkan
```

### 混合使用（实验性）
```bash
# 需要 llama.cpp 支持多 GPU 分割
llama-cli -m model.gguf -ngl 99 -fa --tensor_split 12,16
```

## 📋 系统要求

### Linux
- Ubuntu 18.04+ / Debian 10+ / CentOS 8+
- Vulkan 1.2+
- NVIDIA 驱动 535+ (使用 RTX 3060)
- Mesa Vulkan 驱动 (使用 MI50)

### macOS
- macOS 10.15+
- Homebrew
- MoltenVK

## 🐛 故障排查

### Vulkan 检测不到 GPU
```bash
# 检查驱动
nvidia-smi  # NVIDIA
lspci | grep -i vga  # 所有 GPU

# 检查 Vulkan ICD
vulkaninfo --summary | grep -i "device"
```

### MI50 加载失败
```bash
# 确保设置了 gfx 版本
export HSA_OVERRIDE_GFX_VERSION=9.0.6

# 重新加载驱动
sudo modprobe -r amdgpu
sudo modprobe amdgpu
```

### llama.cpp 不使用 GPU
```bash
# 启用详细输出查看
llama-cli -m model.gguf -ngl 99 -v 2>&1 | grep -i "gpu"

# 确认编译时启用了 GPU 支持
llama-cli --help | grep -i "device"
```

## 📚 相关链接

- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
- [Vulkan 官方文档](https://www.vulkan.org/)
- [AMD ROCm 文档](https://rocm.docs.amd.com/)
- [NVIDIA CUDA 文档](https://developer.nvidia.com/cuda-toolkit)

## 📝 注意事项

1. **MI50 是老旧架构** (gfx906)，部分新功能可能不支持
2. **混合 GPU 使用** 可能不稳定，建议优先使用单一 GPU
3. **显存限制**：模型大小不能超过单个 GPU 的显存
4. **重启生效**：驱动安装后需要重启系统

## ⚠️ 免责声明

使用本脚本即表示您了解相关风险。请确保：
- 备份重要数据
- 了解所安装软件的功能
- 在测试环境验证后再用于生产
