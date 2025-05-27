#!/bin/bash

info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# 必须以 root 运行
if [[ $EUID -ne 0 ]]; then
   error "请以 root 权限运行此脚本"
   exit 1
fi

# 检测 Ubuntu 版本号
UBUNTU_VERSION=$(lsb_release -rs)
CODENAME=$(lsb_release -cs)
info "检测到 Ubuntu $UBUNTU_VERSION（代号 $CODENAME）"

# 更换国内镜像源为清华源
info "切换 apt 源为清华镜像..."
cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-security main restricted universe multiverse
EOF

# 更新系统
info "更新系统软件..."
apt update && apt upgrade -y

# 安装常用工具
info "安装常用工具..."
apt install -y curl wget vim git unzip gnupg lsb-release ca-certificates build-essential dkms software-properties-common

# 禁用 Nouveau 驱动
info "禁用 Nouveau（开源显卡驱动）..."
cat > /etc/modprobe.d/blacklist-nouveau.conf <<EOF
blacklist nouveau
options nouveau modeset=0
EOF

update-initramfs -u

# 添加 NVIDIA 驱动源
info "添加 NVIDIA 官方驱动源（PPA）..."
add-apt-repository ppa:graphics-drivers/ppa -y
apt update

# 安装推荐的闭源驱动
info "安装推荐的 NVIDIA 驱动..."
ubuntu-drivers devices
ubuntu-drivers autoinstall

# 安装 nvtop
info "安装 nvtop（显卡实时监控工具）..."
apt install -y cmake libncurses5-dev libncursesw5-dev git pkg-config libdrm-dev libpci-dev

if apt-cache show nvtop > /dev/null 2>&1; then
    apt install -y nvtop
else
    cd /tmp
    git clone https://github.com/Syllo/nvtop.git
    cd nvtop
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    make install
fi

info "✅ 安装全部完成！建议现在重启系统："
echo -e "\n\033[1;33mreboot\033[0m"
