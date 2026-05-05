#!/bin/bash
################################################################################
# 骰子助记词生成器 - 痕迹清理脚本
# 用途：擦除生成助记词后可能留下的敏感数据痕迹
# 使用：./clean-mnemonic-traces.sh
################################################################################

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  骰子助记词生成器 - 痕迹清理脚本${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

################################################################################
# 1. 清理剪贴板 (X11 & Wayland)
################################################################################
echo -e "${YELLOW}[1/7]${NC} 清理剪贴板..."

# X11 剪贴板
if command -v xclip &> /dev/null; then
    # 清空所有剪贴板选择
    echo -n "" | xclip -selection clipboard 2>/dev/null || true
    echo -n "" | xclip -selection primary 2>/dev/null || true
    echo -n "" | xclip -selection secondary 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} X11 剪贴板已清空"
elif command -v xsel &> /dev/null; then
    xsel --clipboard --clear 2>/dev/null || true
    xsel --primary --clear 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} X11 剪贴板已清空"
fi

# Wayland 剪贴板
if command -v wl-paste &> /dev/null; then
    if command -v wl-copy &> /dev/null; then
        echo -n "" | wl-copy 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} Wayland 剪贴板已清空"
    fi
fi

################################################################################
# 2. 清理浏览器缓存和数据
################################################################################
echo -e "${YELLOW}[2/7]${NC} 清理浏览器缓存..."

# 清理当前用户的浏览器缓存
USER_CACHE_DIR="$HOME/.cache"
BROWSER_CACHE_DIRS=(
    "$HOME/.config/google-chrome/Default/Service Worker"
    "$HOME/.config/google-chrome/Default/Local Storage"
    "$HOME/.config/chromium/Default/Service Worker"
    "$HOME/.config/chromium/Default/Local Storage"
    "$HOME/.mozilla/firefox/*/storage"
    "$HOME/.cache/mozilla/firefox/*/cache2"
)

for dir in "${BROWSER_CACHE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # 只清理会话存储和本地存储，不清空整个缓存
        find "$dir" -type f -delete 2>/dev/null || true
    fi
done

# 清理基于WebKit的浏览器 (如Epiphany, Midori)
if [ -d "$HOME/.local/share/webkitgtk" ]; then
    rm -rf "$HOME/.local/share/webkitgtk"/{databases,localStorage,IndexedDB} 2>/dev/null || true
fi

echo -e "  ${GREEN}✓${NC} 浏览器敏感缓存已清理"

################################################################################
# 3. 清理 Shell 历史
################################################################################
echo -e "${YELLOW}[3/7]${NC} 清理 Shell 历史..."

# 清理当前会话历史
history -c 2>/dev/null || true
history -w 2>/dev/null || true

# 清理 bash_history 文件中的敏感行（助记词相关）
HISTORY_FILES=(
    "$HOME/.bash_history"
    "$HOME/.zsh_history"
    "$HOME/.history"
)

for hist_file in "${HISTORY_FILES[@]}"; do
    if [ -f "$hist_file" ]; then
        # 备份
        cp "$hist_file" "${hist_file}.bak"
        # 移除包含助记词特征的行（12或24个英文单词）
        grep -vE '^[a-zA-Z]+( [a-zA-Z]+){11,23}$' "$hist_file" > "${hist_file}.tmp" 2>/dev/null || true
        mv "${hist_file}.tmp" "$hist_file" 2>/dev/null || true
        # 覆盖并删除备份
        shred -u "${hist_file}.bak" 2>/dev/null || rm -f "${hist_file}.bak"
    fi
done

echo -e "  ${GREEN}✓${NC} Shell 历史已清理"

################################################################################
# 4. 清理临时文件
################################################################################
echo -e "${YELLOW}[4/7]${NC} 清理临时文件..."

TEMP_DIRS=(
    "/tmp"
    "$HOME/.cache"
    "$HOME/tmp"
)

# 查找并清理可能包含助记词的临时文件
find /tmp -maxdepth 2 -type f \( -name "*.html" -o -name "*mnemonic*" -o -name "*seed*" \) -mmin -60 -delete 2>/dev/null || true

# 清理缩略图缓存（可能包含截图）
find "$HOME/.cache/thumbnails" -type f -mmin -60 -delete 2>/dev/null || true

# 清理最近文件列表（部分桌面环境）
if [ -f "$HOME/.local/share/recently-used.xbel" ]; then
    touch "$HOME/.local/share/recently-used.xbel"
fi

echo -e "  ${GREEN}✓${NC} 临时文件已清理"

################################################################################
# 5. 清理自动完成和建议缓存
################################################################################
echo -e "${YELLOW}[5/7]${NC} 清理自动完成缓存..."

# 清理 GTK+ 输入历史
if [ -d "$HOME/.local/share/gtk-2.0" ]; then
    find "$HOME/.local/share/gtk-2.0" -name "*.gtkrfc-1.2.history*" -delete 2>/dev/null || true
fi

if [ -d "$HOME/.local/share/gtk-3.0" ]; then
    find "$HOME/.local/share/gtk-3.0" -name "*.gtkrfc-1.2.history*" -delete 2>/dev/null || true
fi

# 清理 Qt 输入历史
if [ -f "$HOME/.config/QtProject.conf" ]; then
    # 备份后移除历史相关部分
    sed -i '/History/d' "$HOME/.config/QtProject.conf" 2>/dev/null || true
fi

# 清理 readline 历史（用于各种工具）
if [ -f "$HOME/.inputrc" ]; then
    # 确保不保存历史
    echo "set history-size 0" > "$HOME/.inputrc"
fi

echo -e "  ${GREEN}✓${NC} 自动完成缓存已清理"

################################################################################
# 6. 清理系统日志中的敏感信息（仅用户可访问的部分）
################################################################################
echo -e "${YELLOW}[6/7]${NC} 清理用户日志..."

# 清理 systemd 用户日志（如果可访问）
if command -v journalctl &> /dev/null; then
    journalctl --user --rotate &>/dev/null || true
    journalctl --user --vacuum-time=1s &>/dev/null || true
fi

# 清理 .xsession-errors（常见的 X11 会话日志）
if [ -f "$HOME/.xsession-errors" ]; then
    > "$HOME/.xsession-errors"
fi

if [ -f "$HOME/.xsession-errors.old" ]; then
    > "$HOME/.xsession-errors.old"
fi

echo -e "  ${GREEN}✓${NC} 用户日志已清理"

################################################################################
# 7. 内存清理（尽可能）
################################################################################
echo -e "${YELLOW}[7/7]${NC} 尝试内存清理..."

# 同步文件系统
sync

# 尝试释放页面缓存、目录项和inode（需要root权限）
if [ "$EUID" -eq 0 ]; then
    echo "3" > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} 系统缓存已释放（root权限）"
else
    echo -e "  ${YELLOW}⊙${NC} 内存清理需要root权限，跳过"
    echo -e "     如需清理，请运行: sudo bash -c 'echo 3 > /proc/sys/vm/drop_caches'"
fi

# 交换分区清理（需要大量内存操作，默认跳过）
echo -e "  ${YELLOW}⊙${NC} 交换分区清理需要大量内存，已跳过"
echo -e "     如需清理交换分区，请运行: sudo swapoff -a && swapon -a"

################################################################################
# 完成
################################################################################
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  清理完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}注意事项：${NC}"
echo "  1. 某些数据可能仍驻留在交换分区或休眠镜像中"
echo "  2. 如需彻底清理，建议重启系统"
echo "  3. 浏览器的扩展程序可能已保存数据，请手动检查"
echo "  4. 云同步服务可能已上传数据，请检查云端"
echo ""
echo -e "${RED}⚠️  建议立即重启系统以彻底清理内存！${NC}"
echo ""
