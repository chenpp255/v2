#!/usr/bin/env sh

set -e

# Don't use Ubuntu Snap
PATH="$(echo "$PATH" | sed 's|:/snap/bin||g')"
export PATH

# Color
if command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
fi

# SHA256SUM
if command -v sha256sum >/dev/null 2>&1; then
    SHA256SUM() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    SHA256SUM() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v openssl >/dev/null 2>&1; then
    SHA256SUM() { openssl dgst -sha256 "$1" | awk '{print $2}'; }
elif command -v busybox >/dev/null 2>&1; then
    SHA256SUM() { busybox sha256sum "$1" | awk '{print $1}'; }
fi

# Must be root
if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}Error: Must run as root!${RESET}" >&2
    exit 1
fi

# Check tools
for tool in wget unzip; do
    if ! command -v $tool >/dev/null 2>&1; then
        tool_need="$tool $tool_need"
    fi
done
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
    tool_need="openssl $tool_need"
fi
if [ -n "$tool_need" ]; then
    if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y $tool_need
    else
        echo "$RED Please install $tool_need manually $RESET"
        exit 1
    fi
fi

notice_installled_tool() {
    if [ -n "$tool_need" ]; then
        echo "${GREEN}Installed dependencies: $tool_need${RESET}"
    fi
}

# Arch
case $(uname -m) in
x86_64) arch="64"; arch2="x64";;
armv7l) arch="arm32-v7a"; arch2="armv7";;
aarch64) arch="arm64-v8a"; arch2="arm64";;
riscv64) arch="riscv64"; arch2="riscv64";;
*) echo "$RED Unsupported arch $RESET"; exit 1;;
esac

# Versions
v2ray_url="https://ghproxy.com/https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-$arch.zip"
v2raya_ver=$(wget -qO- https://ghproxy.com/https://api.github.com/repos/v2rayA/v2rayA/releases/latest | grep tag_name | cut -d '"' -f4)
v2raya_short=${v2raya_ver#v}
v2raya_url="https://ghproxy.com/https://github.com/v2rayA/v2rayA/releases/download/$v2raya_ver/v2raya_linux_${arch2}_$v2raya_short"
service_url="https://ghproxy.com/https://raw.githubusercontent.com/v2rayA/v2rayA-installer/main/systemd/v2raya.service"

# Download and install v2ray
wget -O /tmp/v2ray.zip "$v2ray_url"
wget -O /tmp/v2ray.dgst "$v2ray_url.dgst"
if [ "$(SHA256SUM /tmp/v2ray.zip)" != "$(awk -F '= ' '/256=/ {print $2}' < /tmp/v2ray.dgst)" ]; then
    echo "$RED v2ray hash mismatch $RESET"; exit 1
fi
unzip -q /tmp/v2ray.zip -d /tmp/v2ray
install /tmp/v2ray/v2ray /usr/local/bin/v2ray
mkdir -p /usr/local/share/v2ray
mv /tmp/v2ray/geo*.dat /usr/local/share/v2ray

# Download and install v2raya
wget -O /tmp/v2raya "$v2raya_url"
wget -O /tmp/v2raya.sha256.txt "$v2raya_url.sha256.txt"
if [ "$(SHA256SUM /tmp/v2raya)" != "$(cat /tmp/v2raya.sha256.txt)" ]; then
    echo "$RED v2rayA hash mismatch $RESET"; exit 1
fi
install /tmp/v2raya /usr/local/bin/v2raya
wget -O /etc/systemd/system/v2raya.service "$service_url"
systemctl daemon-reexec
systemctl daemon-reload

# 创建密码重置脚本
cat >/usr/local/bin/v2raya-reset-password <<EOF
#!/bin/sh
v2raya -c /usr/local/etc/v2raya --reset-password
EOF
chmod +x /usr/local/bin/v2raya-reset-password

# 启动并启用服务
systemctl start v2raya
systemctl enable v2raya

notice_installled_tool

echo "\n${GREEN}v2rayA 安装成功并已设置开机自启！${RESET}"
echo "访问面板：http://<服务器IP>:2017"
echo "默认用户名：admin，密码为空（可运行 v2raya-reset-password 重置）"
echo "配置目录：/usr/local/etc/v2raya"
echo "卸载方式：删除 /usr/local/bin/v2raya 与服务文件即可"
echo "官网：https://v2raya.org"
