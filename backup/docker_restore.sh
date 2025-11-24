#!/bin/sh

# --- 颜色定义 ---
red() { echo -e "\033[31m\033[01m[CRITICAL] $1\033[0m"; }
green() { echo -e "\033[32m\033[01m[INFO] $1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m[WARNING] $1\033[0m"; }
blue() { echo -e "\033[34m\033[01m[MESSAGE] $1\033[0m"; }
light_magenta() { echo -e "\033[95m\033[01m[NOTICE] $1\033[0m"; }

# --- 配置 ---
# 您的 Docker 数据根目录
DOCKER_ROOT_DIR="/mnt/mydisk/docker"
# 备份文件上传目录
UPLOAD_DIR="/tmp/upload"
# 备份文件固定名称
BACKUP_FILENAME="docker_data_backup.tar.gz"
# Docker 服务控制脚本名称
DOCKER_SERVICE_SCRIPT="/etc/init.d/dockerd"
# 完整的备份文件路径
FULL_BACKUP_FILE="$UPLOAD_DIR/$BACKUP_FILENAME"

# --- 恢复函数 ---
restore_docker() {
    blue "--- Docker 数据恢复程序启动 ---"
    
    # 1. 检查文件和环境
    if [ ! -f "$FULL_BACKUP_FILE" ]; then
        red "错误：未找到备份文件 $FULL_BACKUP_FILE。"
        red "请确认文件已上传到 $UPLOAD_DIR 目录下。"
        return 1
    fi
    if [ ! -f "$DOCKER_SERVICE_SCRIPT" ]; then
        red "错误：未找到 Docker 服务控制脚本 ($DOCKER_SERVICE_SCRIPT)。无法停止服务。"
        return 1
    fi
    if [ ! -d "$DOCKER_ROOT_DIR" ]; then
        red "错误：Docker 数据目录 $DOCKER_ROOT_DIR 不存在。请先挂载或创建该目录。"
        return 1
    fi

    # 2. 停止 Docker 服务 (关键步骤)
    yellow "正在停止 Docker 服务 ($DOCKER_SERVICE_SCRIPT stop)..."
    "$DOCKER_SERVICE_SCRIPT" stop || { red "无法停止 Docker 服务，恢复操作中止。"; return 1; }
    sleep 3 
    
    # 3. 清空现有 Docker 数据目录 (!!! 危险操作 !!!)
    light_magenta "--- WARNING ---"
    yellow "即将清空并删除 $DOCKER_ROOT_DIR 目录下的所有现有 Docker 数据！"
    light_magenta "--- WARNING ---"
    
    # 询问用户确认，防止误操作
    read -p "您确定要清空并恢复Docker数据吗? (输入 'YES' 确认): " CONFIRMATION

    if [ "$CONFIRMATION" != "YES" ]; then
        red "用户取消操作。正在重启 Docker 服务并退出。"
        "$DOCKER_SERVICE_SCRIPT" start
        return 1
    fi

    green "用户已确认。正在删除旧数据..."
    # 确保只删除 DOCKER_ROOT_DIR 内部的内容
    if rm -rf "$DOCKER_ROOT_DIR"/* "$DOCKER_ROOT_DIR"/.* 2>/dev/null; then
        green "旧数据已清空。"
    else
        yellow "清空旧数据时发生警告 (可能目录为空)，继续恢复..."
    fi

    # 4. 解压备份文件到 Docker Root 目录
    yellow "正在解压备份文件 $BACKUP_FILENAME 到 $DOCKER_ROOT_DIR..."
    
    # -x: 解压 (Extract)
    # -z: gzip 格式
    # -v: 显示详细日志
    # -f: 指定文件名
    # -C: 指定解压目录
    # 注意: 我们需要解压后的 'docker' 文件夹内容直接进入 $DOCKER_ROOT_DIR
    if tar -xzvf "$FULL_BACKUP_FILE" -C "$(dirname "$DOCKER_ROOT_DIR")"; then
        green "数据解压完成。容器、镜像和卷已恢复。"
    else
        red "解压备份文件失败。请检查文件完整性或磁盘空间。"
        "$DOCKER_SERVICE_SCRIPT" start # 尝试启动服务
        return 1
    fi

    # 5. 启动 Docker 服务
    yellow "正在重启 Docker 服务 ($DOCKER_SERVICE_SCRIPT start)..."
    "$DOCKER_SERVICE_SCRIPT" start || { red "Docker 服务启动失败，请手动检查！"; }
    
    green "--- 恢复完成 ---"
    green "请等待服务完全启动，然后检查您的 Docker 容器是否正常。"
}

# --- 执行函数 ---
restore_docker