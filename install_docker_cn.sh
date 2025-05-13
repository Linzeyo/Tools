#!/bin/bash

# 脚本名称: install_docker_cn.sh
# 描述: 在基于 RHEL 的系统 (如 CentOS Stream 9, openEuler 等) 上使用国内镜像站安装 Docker CE。
# 作者: Ethan
# 日期: 2025年5月13日

# --- 配置选项 ---
# 默认使用阿里云镜像。如需更换，请修改此变量。
# 可选值：
#   Aliyun (阿里云): mirrors.aliyun.com/docker-ce
#   Tuna (清华大学): mirrors.tuna.tsinghua.edu.cn/docker-ce
DOCKER_MIRROR_DOMAIN="mirrors.aliyun.com/docker-ce"

# --- 脚本正文 ---

# 错误处理函数
handle_error() {
    echo -e "\n❌ 错误: $1" >&2
    echo "脚本执行中断。" >&2
    exit 1
}

# 检查是否是 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ 请使用 root 用户或 sudo 运行此脚本。"
    exit 1
fi

# 检查是否是 DNF 包管理器存在的系统
if ! command -v dnf &> /dev/null; then
    handle_error "未找到 'dnf' 命令。此脚本适用于使用 DNF 包管理器的系统 (如 CentOS Stream, openEuler)。"
fi

echo "🚀 开始使用国内镜像站 (${DOCKER_MIRROR_DOMAIN}) 安装 Docker CE..."

# 定义 Docker 仓库的完整 URL
DOCKER_REPO_BASE_URL="https://${DOCKER_MIRROR_DOMAIN}/linux/centos/docker-ce.repo"
# 定义用于替换 URL 的 sed 模式
DOCKER_REPLACE_PATTERN="s/download.docker.com/${DOCKER_MIRROR_DOMAIN}/g"

echo "✨ 步骤 1/6: 移除旧的 Docker 仓库配置 (如果存在)..."
sudo rm -f /etc/yum.repos.d/docker-ce.repo || echo "未找到旧的 Docker 仓库文件，跳过移除。"

echo "✨ 步骤 2/6: 添加 Docker 国内镜像仓库..."
sudo dnf config-manager --add-repo "${DOCKER_REPO_BASE_URL}" || handle_error "添加 Docker 仓库失败，请检查网络或镜像地址是否正确。"

# 检查 repo 文件是否创建成功，并修改 baseurl
REPO_FILE="/etc/yum.repos.d/docker-ce.repo"
if [ -f "$REPO_FILE" ]; then
    echo "✨ 步骤 3/6: 修改仓库配置文件以使用镜像源..."
    sudo sed -i "${DOCKER_REPLACE_PATTERN}" "$REPO_FILE" || handle_error "修改仓库配置文件失败，请检查文件权限或 sed 命令。"
else
    handle_error "Docker 仓库文件 '${REPO_FILE}' 未创建成功，请检查网络或 DNF 配置。"
fi

echo "✨ 步骤 4/6: 清理 DNF 缓存并生成新的缓存..."
sudo dnf clean all || handle_error "清除 DNF 缓存失败。"
sudo dnf makecache || handle_error "生成 DNF 缓存失败，请检查网络或仓库配置。"

echo "✨ 步骤 5/6: 安装 Docker Engine, Containerd 和 Docker Compose 插件..."
# 建议卸载旧版本 Docker (如果存在的话)，避免冲突
sudo dnf remove docker \
                   docker-client \
                   docker-client-latest \
                   docker-common \
                   docker-latest \
                   docker-latest-logrotate \
                   docker-logrotate \
                   docker-engine -y > /dev/null 2>&1
# 安装必要的工具和依赖
sudo dnf install -y dnf-utils device-mapper-persistent-data lvm2 || handle_error "安装 Docker 依赖失败。"
# 安装 Docker CE 核心组件
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || handle_error "安装 Docker 组件失败，请检查仓库配置或网络。"

echo "✨ 步骤 6/6: 启动 Docker 服务并设置开机自启..."
sudo systemctl start docker || handle_error "启动 Docker 服务失败。"
sudo systemctl enable docker || handle_error "设置 Docker 服务开机自启失败。"

echo "🎉 Docker 安装成功！"

echo -e "\n--- 后续步骤 ---"
echo "1. 验证 Docker 安装："
echo "   执行命令: sudo docker run hello-world"
echo "   如果显示 'Hello from Docker!'，则表示安装成功。"

echo "2. (可选) 将您的普通用户添加到 'docker' 组，以便无需 'sudo' 即可运行 Docker 命令："
echo "   如果您想添加的用户不是 'root'，请替换 '<您的用户名>' 为您实际的普通用户，例如 'youruser'："
echo "   sudo usermod -aG docker <您的用户名>"
echo "   执行此命令后，请注销当前会话并重新登录，或运行 'newgrp docker' 命令以使更改生效。"
echo "   (推荐注销并重新登录)"

echo "3. (可选) 配置 Docker 镜像加速器 (提高 Docker 镜像下载速度)："
echo "   您可以参考阿里云、腾讯云或其他云服务商的容器服务文档，获取专属的 Docker 镜像加速器地址。"
echo "   通常，您需要在 /etc/docker/daemon.json 文件中添加如下配置："
echo "   sudo mkdir -p /etc/docker"
echo "   echo '{ \"registry-mirrors\": [\"https://<您的加速器ID>.mirror.aliyuncs.com\"] }' | sudo tee /etc/docker/daemon.json"
echo "   sudo systemctl restart docker"