#!/bin/bash
set -e

# 检查并安装必要依赖
need_pkgs=""
for pkg in wget unzip openssl; do
  if ! command -v $pkg &>/dev/null; then
    need_pkgs="$need_pkgs $pkg"
  fi
done
if [ -n "$need_pkgs" ]; then
  apt update
  apt install -y $need_pkgs
fi

# 获取架构
case $(uname -m) in
  x86_64) arch="64"; arch2="x64";;
  aarch64) arch="arm64-v8a"; arch2="arm64";;
  armv7l) arch="arm32-v7a"; arch2="armv7";;
  *) echo "Unsupported arch"; exit 1;;
esac

# 使用 ghproxy 加速下载
v2ray_url="https://ghproxy.com/https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-${arch}.zip"
v2raya_ver=$(wget -qO- https://ghproxy.com/https://api.github.com/repos/v2rayA/v2rayA/releases/latest | grep tag_name | cut -d '"' -f4)
v2raya_short=${v2raya_ver#v}
v2raya_url="https://ghproxy.com/https://github.com/v2rayA/v2rayA/releases/download/${v2raya_ver}/v2raya_linux_${arch2}_${v2raya_short}"
service_url="https://ghproxy.com/https://raw.githubusercontent.com/v2rayA/v2rayA-installer/main/systemd/v2raya.service"

# 下载 v2ray
wget -O /tmp/v2ray.zip "$v2ray_url" || { echo "❌ 下载 v2ray 失败"; exit 1; }
unzip -qo /tmp/v2ray.zip -d /tmp/v2ray
install /tmp/v2ray/v2ray /usr/local/bin/v2ray
mkdir -p /usr/local/share/v2ray
mv /tmp/v2ray/geo*.dat /usr/local/share/v2ray

# 下载 v2rayA
wget -O /tmp/v2raya "$v2raya_url" || { echo "❌ 下载 v2rayA 失败"; exit 1; }
install /tmp/v2raya /usr/local/bin/v2raya
wget -O /etc/systemd/system/v2raya.service "$service_url"

# 创建密码重置脚本
cat >/usr/local/bin/v2raya-reset-password <<EOF
#!/bin/sh
v2raya -c /usr/local/etc/v2raya --reset-password
EOF
chmod +x /usr/local/bin/v2raya-reset-password

# 启动并启用服务
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable v2raya
systemctl start v2raya

echo -e "\n✅ v2ray + v2rayA 安装完成（无系统代理）"
echo "🔗 面板地址：http://<你的服务器IP>:2017"
echo "🔑 默认账户：admin 密码为空，可使用 v2raya-reset-password 重设"

/usr/local/bin/proxyon

echo -e "\n✅ v2ray + v2rayA 安装完成，已配置国内加速与全局代理"
echo "🔗 管理面板：http://<你的服务器IP>:2017"
echo "🔑 默认账户：admin 密码为空，可使用 v2raya-reset-password 重设"
