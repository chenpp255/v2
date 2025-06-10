#!/bin/bash
set -e

PROXY="http://127.0.0.1:20171"

# 设定系统代理（防止 GitHub 下载失败）
export http_proxy="$PROXY"
export https_proxy="$PROXY"

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

# 写入系统全局代理（proxyon）
cat >/usr/local/bin/proxyon <<EOF
#!/bin/bash
PROXY="$PROXY"
export http_proxy="\$PROXY"
export https_proxy="\$PROXY"

echo "写入 /etc/environment..."
grep -q 'http_proxy' /etc/environment || echo "http_proxy=\$PROXY" >> /etc/environment
grep -q 'https_proxy' /etc/environment || echo "https_proxy=\$PROXY" >> /etc/environment

echo "写入 /etc/apt/apt.conf.d/99proxy..."
echo 'Acquire::http::Proxy "\$PROXY";' > /etc/apt/apt.conf.d/99proxy
echo 'Acquire::https::Proxy "\$PROXY";' >> /etc/apt/apt.conf.d/99proxy

echo "写入 Git 配置..."
for user in /root /home/*; do
  if [ -d "\$user" ]; then
    sudo -u \$(basename "\$user") git config --global http.proxy "\$PROXY" 2>/dev/null || true
    sudo -u \$(basename "\$user") git config --global https.proxy "\$PROXY" 2>/dev/null || true
  fi
done

echo "写入 Docker 代理..."
mkdir -p /etc/systemd/system/docker.service.d
cat <<DOCKER > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=\$PROXY" "HTTPS_PROXY=\$PROXY"
DOCKER

systemctl daemon-reexec
systemctl daemon-reload
systemctl restart docker 2>/dev/null || true

echo "✅ 全局代理设置完成"
EOF

chmod +x /usr/local/bin/proxyon
/usr/local/bin/proxyon

echo -e "\n✅ v2ray + v2rayA 安装完成，已配置国内加速与全局代理"
echo "🔗 管理面板：http://<你的服务器IP>:2017"
echo "🔑 默认账户：admin 密码为空，可使用 v2raya-reset-password 重设"
