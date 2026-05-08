# 🚨 紧急恢复指南 - MI50 显示问题

## 症状

- 重启后屏幕只显示一个光标
- 桌面环境无法加载
- 黑屏但有光标

## 原因

**AMD MI50 是纯计算卡，没有视频输出接口！**

如果系统错误地将显示输出指向 MI50，会导致黑屏。

---

## 🚑 紧急恢复步骤

### 方法 1: SSH 远程修复（推荐）

如果另一台机器可以 SSH 连接：

```bash
# 从另一台机器 SSH 到问题机器
ssh your-username@your-computer-ip

# 运行修复脚本
sudo ~/llama-vulkan-setup/fix-display.sh

# 选择选项 1（恢复默认显示设置）

# 重启
sudo reboot
```

### 方法 2: 本地终端修复

1. **切换到文本控制台**
   - 按 `Ctrl + Alt + F2` 到 `F6` 中的任意一个
   - 应该能看到登录提示符

2. **登录**
   ```bash
   login: your-username
   Password: ********
   ```

3. **运行修复命令**
   ```bash
   # 移除 MI50 显示配置
   sudo sed -i '/HSA_OVERRIDE_GFX_VERSION/d' /etc/profile.d/rocm.sh 2>/dev/null || true
   sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.zshrc 2>/dev/null || true
   sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.bashrc 2>/dev/null || true
   ```

4. **重启系统**
   ```bash
   sudo reboot
   ```

### 方法 3: GRUB 临时修复

如果无法登录：

1. **重启电脑**

2. **在 GRUB 菜单出现时，按 `e` 编辑启动参数**

3. **找到以 `linux` 开头的那一行**

4. **在行末添加**：
   ```
   amdgpu.sg_display=0
   ```

5. **按 `F10` 或 `Ctrl + X` 启动**

6. **进入系统后，永久修复**：
   ```bash
   sudo ~/llama-vulkan-setup/fix-display.sh
   ```

---

## 🛠️ 永久修复

### 步骤 1: 运行修复脚本

```bash
sudo ~/llama-vulkan-setup/fix-display.sh
```

选择选项 **1**（恢复默认显示设置）

### 步骤 2: 手动清理配置（如果脚本不可用）

```bash
# 移除 MI50 相关的环境变量配置
sudo sed -i '/HSA_OVERRIDE_GFX_VERSION/d' /etc/profile.d/rocm.sh 2>/dev/null || true
sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.zshrc 2>/dev/null || true
sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.bashrc 2>/dev/null || true
sudo sed -i '/ROCM_VISIBLE_DEVICES/d' ~/.zshrc 2>/dev/null || true
```

### 步骤 3: 重启

```bash
sudo reboot
```

---

## ✅ 验证修复

重启后，应该能正常进入桌面。

检查 GPU 配置：
```bash
# 查看 GPU 列表
lspci | grep -i vga
lspci | grep -i display

# 查看 Vulkan 设备
vulkaninfo --summary | grep deviceName
```

---

## 🔧 正确使用 MI50

MI50 应该仅用于计算任务，不要作为显示设备。

### 运行 llama.cpp 时指定 MI50

```bash
# 使用 MI50 进行计算（显示由其他 GPU 负责）
llama-cli -m ~/models/model.gguf -ngl 99 -fa --device vulkan --gpu 1

# 注意：--gpu 参数根据实际设备索引调整
# 通常 MI50 是第二个设备（索引 1）
```

### 查看 GPU 索引

```bash
vulkaninfo --summary
```

输出示例：
```
deviceName = AMD Radeon Graphics (RADV VEGA20)  # 索引 0 - 显示用
deviceName = AMD Radeon MI50                     # 索引 1 - 计算用
```

---

## 📋 预防下次发生

### 在运行 gpu-selector.sh 时

1. **不要选择 MI50 作为显示设备**
2. **选择集成显卡或 NVIDIA 显卡作为主显示**
3. **MI50 仅用于 llama.cpp 计算任务**

### 推荐的 gpu-selector.sh 配置

```
选择 GPU 时：
- 选择 "AMD Radeon Graphics" 或 "NVIDIA RTX 3060" 作为主显示
- MI50 留作计算用

运行 llama.cpp 时手动指定：
llama-cli -m model.gguf --device vulkan --gpu 1
```

---

## 🆘 如果仍然无法恢复

### 使用 Live USB

1. 制作 Ubuntu Live USB
2. 从 USB 启动
3. 挂载原系统分区
4. 编辑配置文件：
   ```bash
   sudo mount /dev/sdX1 /mnt  # 替换为实际分区
   sudo chroot /mnt
   rm /etc/profile.d/rocm.sh
   sudo sed -i '/VULKAN_DEVICE_INDEX/d' ~/.zshrc
   exit
   sudo reboot
   ```

### 完全重装驱动

```bash
# 卸载 AMD 驱动
sudo apt remove --purge -y amdgpu-dev mesa-vulkan-drivers

# 重新安装基础驱动
sudo apt install -y xserver-xorg-video-amdgpu

# 重启
sudo reboot
```

---

## 📞 获取帮助

如果以上方法都无效：

1. 查看系统日志：
   ```bash
   sudo journalctl -xb | grep -i "gpu\|display\|drm"
   ```

2. 检查 Xorg 日志：
   ```bash
   cat /var/log/Xorg.0.log
   ```

3. 在 GitHub 提交 issue：
   https://github.com/EdwQ/llama-vulkan-setup/issues

---

## 📚 参考资料

- [AMD GPU 文档](https://wiki.archlinux.org/title/AMDGPU)
- [ROCm 文档](https://rocm.docs.amd.com/)

---

**记住：MI50 是计算卡，不是显示卡！** 🚫🖥️
