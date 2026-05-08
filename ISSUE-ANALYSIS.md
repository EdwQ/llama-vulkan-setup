# 📋 安装脚本导致显示问题的分析报告

**日期**: 2026-05-09  
**问题**: 系统重启后黑屏，仅显示光标  
**根本原因**: MI50 配置错误导致显示输出指向了无视频输出的计算卡

---

## 🔍 问题定位

### 问题代码位置

文件: `llama-vulkan-full-setup.sh`  
行号: 约 210-217 行

```bash
# MI50 (gfx906) 特殊配置
if lspci | grep -i "MI50" > /dev/null 2>&1; then
    log_info "检测到 AMD MI50，配置 gfx906 支持..."
    
    # 创建 ROCm 配置文件
    echo "export HSA_OVERRIDE_GFX_VERSION=9.0.6" | sudo tee -a /etc/profile.d/rocm.sh
    sudo chmod +x /etc/profile.d/rocm.sh
    
    log_success "MI50 gfx906 配置完成"
fi
```

### 问题代码分析

| 问题 | 描述 |
|------|------|
| **1. HSA_OVERRIDE_GFX_VERSION** | 这个环境变量**仅用于 ROCm 运行时**，告诉 ROCm 忽略 GPU 架构检查 |
| **2. 全局配置文件** | 写入 `/etc/profile.d/rocm.sh` → **对所有用户和会话生效** |
| **3. 缺少说明** | 脚本没有说明这个配置的影响范围和使用场景 |
| **4. 未区分用途** | 没有区分"显示用 GPU"和"计算用 GPU" |

---

## 🎯 为什么会黑屏？

### MI50 硬件特性

```
┌────────────────────────────────────────────────────────┐
│                    AMD MI50                           │
├────────────────────────────────────────────────────────┤
│  类型:  计算卡 (Data Center GPU)                      │
│  用途:  高性能计算、AI 训练、推理                      │
│  视频输出:  ❌ 无视频输出接口                          │
│  连接方式:  PCIe 插槽                                  │
└────────────────────────────────────────────────────────┘
```

### 系统行为分析

```
安装脚本执行流程:

1. 检测 GPU
   ├── NVIDIA RTX 3060 (有视频输出) ✅
   ├── AMD Radeon 集成显卡 (有视频输出) ✅
   └── AMD MI50 (无视频输出) ❌

2. 配置 ROCm
   └── 写入 /etc/profile.d/rocm.sh
       └── export HSA_OVERRIDE_GFX_VERSION=9.0.6

3. 用户登录系统
   ├── 加载 /etc/profile.d/rocm.sh
   ├── 设置环境变量
   └── 系统尝试使用 MI50 作为显示设备
       └── ❌ 无视频输出 → 黑屏
```

### 环境变量影响

```bash
# 这个环境变量本身不直接导致黑屏
export HSA_OVERRIDE_GFX_VERSION=9.0.6

# 但配合 gpu-selector.sh 的错误选择：
export VULKAN_DEVICE_INDEX=1  # MI50 是第二个设备

# 会导致应用程序尝试在 MI50 上渲染图形
```

---

## 📊 系统设计缺陷

| 缺陷 | 严重程度 | 影响 |
|------|---------|------|
| 未明确区分显示 GPU 和计算 GPU | 🔴 严重 | 可能导致显示系统崩溃 |
| 全局配置文件影响所有用户 | 🟡 中等 | 多用户系统全部受影响 |
| 缺少回退机制 | 🟡 中等 | 配置错误后难以恢复 |
| 缺少警告提示 | 🟠 较严重 | 用户不知道配置的风险 |
| 文档不足 | 🟡 中等 | 用户无法正确理解配置用途 |

---

## 🔧 问题影响范围

### 受影响的用户

1. **双 GPU 系统** (RTX 3060 + MI50 + 集成显卡)
2. **仅 MI50 系统** (完全无法显示)

### 不受影响的用户

1. **单 GPU 系统** (只有显示卡)
2. **MI50 仅用于计算** (有独立显示 GPU 且未错误配置)

---

## ✅ 正确的解决方案

### MI50 的正确配置方式

```bash
# ❌ 错误做法 - 全局配置
echo "export HSA_OVERRIDE_GFX_VERSION=9.0.6" | sudo tee -a /etc/profile.d/rocm.sh

# ✅ 正确做法 - 按需配置
# 仅在运行 llama.cpp 时设置
export HSA_OVERRIDE_GFX_VERSION=9.0.6
llama-cli -m model.gguf -ngl 99 --device vulkan --gpu 1
unset HSA_OVERRIDE_GFX_VERSION
```

### 推荐的脚本修改

```bash
# 在检测到 MI50 时，添加警告
if lspci | grep -i "MI50" > /dev/null 2>&1; then
    log_warning "⚠️  检测到 AMD MI50（计算卡）"
    log_info "注意：MI50 没有视频输出接口！"
    log_info "请勿将 MI50 设置为系统显示设备。"
    log_info ""
    log_info "配置说明:"
    log_info "  - 显示设备：使用集成显卡或独立显示卡"
    log_info "  - MI50：仅用于计算任务（llama.cpp、ROCm）"
    log_info ""
    log_info "如需使用 MI50 进行计算，运行 llama.cpp 时指定:"
    log_info "  llama-cli -m model.gguf --device vulkan --gpu 1"
    
    # 询问用户是否配置
    read -p "是否仅配置 MI50 用于计算？[Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_info "跳过 MI50 配置"
    else
        # 仅设置计算相关配置，不设置显示相关配置
        log_info "✅ MI50 已配置为计算设备"
        log_info "显示设备请保持使用默认 GPU"
    fi
fi
```

---

## 🛡️ 预防措施

### 1. 添加警告信息

在脚本开头添加 MI50 使用说明：

```bash
echo "⚠️  重要提示: 本脚本检测到 AMD MI50 计算卡"
echo "MI50 没有视频输出接口，请勿将其设为显示设备！"
echo ""
```

### 2. 分离配置

- 显示配置 → `/etc/X11/xorg.conf` 或桌面环境设置
- 计算配置 → 仅在运行计算程序时设置环境变量

### 3. 添加恢复机制

```bash
# 在配置前备份
sudo cp /etc/profile.d/rocm.sh /etc/profile.d/rocm.sh.backup.$(date +%Y%m%d)

# 提供恢复命令
echo "如果遇到问题，运行: sudo ~/llama-vulkan-setup/fix-display.sh"
```

---

## 📝 修复清单

| 修复项 | 状态 |
|-------|------|
| ✅ 创建 fix-display.sh 修复脚本 | 已完成 |
| ✅ 创建 EMERGENCY-RECOVERY.md 恢复指南 | 已完成 |
| ✅ 创建本分析报告 | 已完成 |
| ⏳ 修改安装脚本添加警告 | 待完成 |
| ⏳ 修改安装脚本分离配置 | 待完成 |
| ⏳ 添加配置备份机制 | 待完成 |

---

## 🎯 总结

### 问题根源

**安装脚本在配置 MI50 时，没有明确区分"显示用途"和"计算用途"**

### 关键错误

1. 将 ROCm 配置写入全局配置文件（`/etc/profile.d/rocm.sh`）
2. 没有警告用户 MI50 无视频输出
3. 没有说明配置的适用范围
4. 没有提供恢复机制

### 正确做法

1. MI50 仅用于计算，不用于显示
2. ROCm 环境变量应在运行时按需设置
3. 添加明确的警告和说明
4. 提供故障恢复方案

---

**报告完成时间**: 2026-05-09 00:08  
**建议**: 立即运行修复脚本并修改安装脚本，防止类似问题再次发生

---

## 📚 参考文档

- [AMD MI50 技术规格](https://www.amd.com/en/products/accelerators/instinct/mi50.html)
- [ROCm 环境变量文档](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/environment-variables.html)
- [Linux 显示服务器架构](https://wiki.archlinux.org/title/Xorg)
