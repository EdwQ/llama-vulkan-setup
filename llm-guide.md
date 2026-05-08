# llama.cpp 使用指南

## 📋 目录
1. [快速开始](#快速开始)
2. [模型准备](#模型准备)
3. [GPU 配置](#gpu-配置)
4. [运行示例](#运行示例)
5. [常用参数](#常用参数)
6. [故障排除](#故障排除)

---

## 快速开始

### 1. 确认安装
```bash
# 检查 llama-cli 是否可用
llama-cli --version

# 检查 Vulkan 是否可用
vulkaninfo --summary | grep deviceName
```

### 2. 运行 GPU 选择器（推荐）
```bash
~/llama-vulkan-setup/gpu-selector.sh
```
这会检测你的 GPU 并设置环境变量。

### 3. 运行基础测试
```bash
# 简单的文本生成测试
llama-cli -m ~/models/<模型文件名.gguf> -n 100 -p "你好"
```

---

## 模型准备

### 下载模型位置
- **国际用户**: https://huggingface.co/models?search=gguf
- **国内用户**: https://modelscope.cn/models?search=gguf

### 推荐模型
| 模型 | 大小 | 适用场景 | 下载链接 |
|------|------|----------|----------|
| Qwen2.5-7B | ~4GB | 日常对话，中文友好 | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF) |
| Qwen2.5-14B | ~8GB | 复杂任务，更好推理 | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-14B-Instruct-GGUF) |
| Llama-3.1-8B | ~4GB | 英文对话 | [HuggingFace](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct-GGUF) |
| Gemma-7B | ~4GB | 通用任务 | [HuggingFace](https://huggingface.co/google/gemma-7b-it-GGUF) |

### 下载命令示例

**使用 huggingface-cli:**
```bash
pip install huggingface-hub
huggingface-cli download Qwen/Qwen2.5-7B-Instruct-GGUF qwen2.5-7b-instruct-q4_k_m.gguf
```

**使用 modelscope-cli (国内推荐):**
```bash
pip install modelscope
modelscope download --model Qwen/Qwen2.5-7B-Instruct-GGUF --revision master qwen2.5-7b-instruct-q4_k_m.gguf
```

**直接使用 wget:**
```bash
# HuggingFace
wget https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf

# ModelScope
wget https://modelscope.cn/api/v1/models/Qwen/Qwen2.5-7B-Instruct-GGUF/repo?Revision=master&FilePath=qwen2.5-7b-instruct-q4_k_m.gguf
```

### 整理模型文件
```bash
# 创建模型目录
mkdir -p ~/models

# 移动模型
mv ~/Downloads/*.gguf ~/models/

# 确认文件
ls -lh ~/models/
```

---

## GPU 配置

### AMD GPU (推荐 Vulkan)
```bash
# 使用 Vulkan 后端
llama-cli -m ~/models/<模型>.gguf -ngl 99 -fa --device vulkan --gpu 0
```

### NVIDIA GPU (推荐 CUDA)
```bash
# 使用 CUDA 后端
llama-cli -m ~/models/<模型>.gguf -ngl 99 -fa --device cuda --gpu 0
```

### 检查 GPU 状态
```bash
# AMD
vulkaninfo --summary | grep -A 5 "deviceName"

# NVIDIA
nvidia-smi
```

---

## 运行示例

### 🎯 交互式聊天模式（推荐）

**AMD GPU:**
```bash
MODEL=~/models/qwen2.5-7b-instruct-q4_k_m.gguf

llama-cli -m $MODEL \
  -ngl 99 -fa --device vulkan --gpu 0 \
  -p "你是一个有用的 AI 助手" \
  -n 1024 -i -cnv
```

**NVIDIA GPU:**
```bash
MODEL=~/models/qwen2.5-7b-instruct-q4_k_m.gguf

llama-cli -m $MODEL \
  -ngl 99 -fa --device cuda --gpu 0 \
  -p "你是一个有用的 AI 助手" \
  -n 1024 -i -cnv
```

### 📝 单次文本生成
```bash
# 生成 512 个 token
llama-cli -m ~/models/qwen2.5-7b-instruct-q4_k_m.gguf \
  -ngl 99 --device vulkan --gpu 0 \
  -p "请介绍你自己" \
  -n 512
```

### 💬 多轮对话（保存会话）
```bash
# 使用 -e 启用 EOF，使用 Ctrl+D 结束输入
llama-cli -m ~/models/qwen2.5-7b-instruct-q4_k_m.gguf \
  -ngl 99 --device vulkan --gpu 0 \
  -i -cnv -p "系统：你是一个助手"
```

### 🧪 性能测试
```bash
# 测试推理速度
llama-bench -m ~/models/qwen2.5-7b-instruct-q4_k_m.gguf \
  -ngl 99 --device vulkan --gpu 0 \
  -n 128
```

---

## 常用参数

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `-m` | 模型路径 | `~/models/<文件名.gguf>` |
| `-ngl` | GPU 层数 | `99` (尽可能多) |
| `-n` / `-n_predict` | 生成 token 数 | `512-2048` |
| `-t` | CPU 线程数 | `4` (根据 CPU 核心数) |
| `-b` / `-n_batch` | 批处理大小 | `2048` |
| `-fa` | 使用 Flash Attention | 始终使用 |
| `-temp` | 温度 (随机性) | `0.7` (平衡) |
| `-top_k` | 采样 top-k | `40` |
| `-top_p` | 采样 top-p | `0.9` |
| `-repeat_penalty` | 重复惩罚 | `1.1` |
| `-i` | 交互模式 | 始终使用 |
| `-cnv` | 对话模式 | 聊天时使用 |
| `-p` | 系统提示 | 自定义 |

### GPU 专用参数

**AMD Vulkan:**
```bash
--device vulkan --gpu 0
```

**NVIDIA CUDA:**
```bash
--device cuda --gpu 0
```

### 显存优化

**小显存 (4-6GB):**
```bash
-ngl 60 -b 1024 -t 2
```

**中等显存 (8-12GB):**
```bash
-ngl 99 -b 2048 -t 4
```

**大显存 (16GB+):**
```bash
-ngl 99 -b 4096 -t 8
```

---

## 故障排除

### 问题 1: "libllama-common.so.0: No such file"
```bash
# 更新动态链接库缓存
sudo ldconfig

# 如果仍然失败，重新运行安装脚本
sudo ~/llama-vulkan-setup/llama-vulkan-full-setup.sh
```

### 问题 2: "Vulkan device not found"
```bash
# 检查 Vulkan 驱动
vulkaninfo --summary

# 检查 AMD 驱动
ls -la /dev/dri/

# 重启系统
sudo reboot
```

### 问题 3: "Out of memory"
```bash
# 减少层数
-ngl 50

# 减少批处理大小
-b 1024

# 使用更小的模型 (q4_0 或 q4_k_m)
```

### 问题 4: 生成速度慢
```bash
# 确保使用 GPU
llama-cli -m $MODEL -ngl 99 --device vulkan --gpu 0

# 检查是否回退到 CPU
# 如果看到 "CPU" 字样，说明 GPU 未启用

# 重启终端，重新运行 gpu-selector.sh
~/llama-vulkan-setup/gpu-selector.sh
```

### 问题 5: 乱码或奇怪输出
```bash
# 确保使用正确的模型和提示词
# 使用 -temp 0.7 降低随机性
# 使用 -repeat_penalty 1.1 减少重复

llama-cli -m $MODEL -temp 0.7 -repeat_penalty 1.1
```

---

## 🎯 一键运行脚本

创建 `~/run-llm.sh`:
```bash
#!/bin/bash

# 设置模型路径 (修改为你的实际模型)
MODEL=~/models/qwen2.5-7b-instruct-q4_k_m.gguf

# 检测 GPU 类型
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    # NVIDIA GPU
    llama-cli -m $MODEL \
      -ngl 99 -fa --device cuda --gpu 0 \
      -p "你是一个有用的 AI 助手" \
      -n 1024 -i -cnv
else
    # AMD GPU
    llama-cli -m $MODEL \
      -ngl 99 -fa --device vulkan --gpu 0 \
      -p "你是一个有用的 AI 助手" \
      -n 1024 -i -cnv
fi
```

设置权限并运行:
```bash
chmod +x ~/run-llm.sh
~/run-llm.sh
```

---

## 📚 更多信息

- **官方文档**: https://github.com/ggml-org/llama.cpp
- **GGUF 格式**: https://github.com/ggml-org/llama.cpp/blob/master/docs/gguf.md
- **社区模型**: https://huggingface.co/models?search=gguf

---

**祝你使用愉快！** 🚀
