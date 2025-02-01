#!/bin/bash

set -e

echo "[INFO] Configuring Zswap..."

# 获取用户输入的 Zswap 参数
echo "请选择压缩算法 (lzo, lz4, lz4hc, deflate):"
read -r compressor
echo "请输入想要的 Zswap 大小 (MB):"
read -r zswap_size
echo "请选择内存池管理算法 (zbud, z3fold):"
read -r zpool

# 定义每种压缩算法所需的模块
declare -A COMPRESSOR_MODULES=(
    ["lzo"]="lzo"
    ["lz4"]="lz4 lz4_compress"
    ["lz4hc"]="lz4 lz4_compress lz4hc_compress"
    ["deflate"]="deflate"
)

# 检测是否需要更新 initramfs
need_update_initramfs=0

# 添加压缩算法所需的模块
if [[ -n "${COMPRESSOR_MODULES[$compressor]}" ]]; then
    for module in ${COMPRESSOR_MODULES[$compressor]}; do
        if ! grep -q "^$module$" /etc/initramfs-tools/modules; then
            echo "$module" >> /etc/initramfs-tools/modules
            echo "[INFO] 添加压缩算法模块: $module"
            need_update_initramfs=1
        fi
    done
else
    echo "[ERROR] 不支持的压缩算法: $compressor"
    exit 1
fi

# 检测并添加内存池管理算法模块
if ! grep -q "^$zpool$" /etc/initramfs-tools/modules; then
    echo "$zpool" >> /etc/initramfs-tools/modules
    echo "[INFO] 添加内存池管理算法模块: $zpool"
    need_update_initramfs=1
fi

# 如果需要更新 initramfs
if [ "$need_update_initramfs" -eq 1 ]; then
    echo "[INFO] 更新 initramfs..."
    update-initramfs -u
else
    echo "[INFO] 无需更新 initramfs，模块已存在。"
fi

# 计算最大内存池百分比
total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_ram_mb=$((total_ram / 1024))
max_pool_percent=$((zswap_size * 100 / total_ram_mb))

echo "计算得到的最大内存池百分比: $max_pool_percent%"

# 更新 GRUB 配置
GRUB_CFG="/etc/default/grub"

# 删除旧的 zswap 配置
sed -i '/zswap\./d' "$GRUB_CFG"

# 删除 GRUB_CMDLINE_LINUX_DEFAULT 前的 # 标志
sed -i '/^#\s*GRUB_CMDLINE_LINUX_DEFAULT=/s/^#\s*//' "$GRUB_CFG"

# 添加新的 zswap 配置
if grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_CFG"; then
    sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/s/\"$/ zswap.enabled=1 zswap.compressor=$compressor zswap.max_pool_percent=$max_pool_percent zswap.zpool=$zpool\"/" "$GRUB_CFG"
else
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=$compressor zswap.max_pool_percent=$max_pool_percent zswap.zpool=$zpool"' >> "$GRUB_CFG"
fi

echo "[INFO] 更新 GRUB 配置..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[INFO] 配置完成。请重启系统以应用更改。"
