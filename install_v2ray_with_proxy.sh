#!/bin/bash

# 安装必需的软件包
echo "安装依赖软件包..."
sudo apt update
sudo apt install -y curl unzip

# 设置V2Ray安装目录
INSTALL_DIR="/usr/local/v2ray"

# 下载并解压V2Ray
echo "下载并解压 V2Ray..."
curl -LO https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
sudo unzip v2ray-linux-64.zip -d $INSTALL_DIR
rm -f v2ray-linux-64.zip

# 创建V2Ray配置目录并配置V2Ray
echo "创建并配置 V2Ray 客户端配置..."
sudo rm -f $INSTALL_DIR/config.json
sudo tee $INSTALL_DIR/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": 1080,
    "listen": "127.0.0.1",
    "protocol": "socks",
    "settings": {
      "udp": true
    }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "aia.vast.pw",
        "port": 28100,
        "users": [{
          "id": "638a3a0b-f9de-4503-a477-ec4f053fb944",
          "encryption": "none",
          "flow": ""
        }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "serverName": "aia.vast.pw",
        "allowInsecure": true
      },
      "wsSettings": {
        "path": "/nnmk",
        "headers": {
          "Host": "aia.vast.pw"
        }
      }
    }
  }]
}
EOF

# 创建 systemd 启动文件
echo "创建 systemd 启动文件..."
sudo tee /etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Client Service
After=network.target

[Service]
ExecStart=$INSTALL_DIR/v2ray -config $INSTALL_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 设置权限并启动服务
echo "设置权限并启动 V2Ray 服务..."
sudo chmod +x $INSTALL_DIR/v2ray
sudo systemctl daemon-reload
sudo systemctl enable v2ray
sudo systemctl start v2ray

# 检查V2Ray服务状态
echo "检查 V2Ray 服务状态..."
sudo systemctl status v2ray --no-pager

# 提示用户安装完成
echo "V2Ray 客户端安装并启动完成！"
echo "可以通过 127.0.0.1:1080 使用 Socks5 代理。"

# 设置全局代理（通过 V2Ray）
echo -e "\n# 🌐 V2Ray 全局代理设置\nexport http_proxy=\"socks5h://127.0.0.1:1080\"\nexport https_proxy=\"socks5h://127.0.0.1:1080\"" >> ~/.bashrc
echo "[INFO] 已添加代理环境变量到 ~/.bashrc"
source ~/.bashrc