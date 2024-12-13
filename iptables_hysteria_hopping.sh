#!/bin/bash

# 函数：检查并安装sudo
install_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo "未检测到sudo命令，正在安装sudo..."
        apt-get update && apt-get install -y sudo
    else
        echo "sudo已安装。"
    fi
}

# 函数：检查并安装iptables-persistent
install_iptables_persistent() {
    if ! dpkg -l | grep -qw iptables-persistent; then
        echo "正在安装iptables-persistent..."
        sudo apt-get update
        sudo apt-get install -y iptables-persistent
    else
        echo "iptables-persistent已安装。"
    fi
}

# 函数：保存规则到文件
save_rules() {
    sudo iptables-save > /etc/iptables/rules.v4
    sudo ip6tables-save > /etc/iptables/rules.v6
}

# 检测当前规则是否永久化
check_persistent_rules() {
    if [ -f /etc/iptables/rules.v4 ] && [ -f /etc/iptables/rules.v6 ]; then
        echo "当前规则已永久化保存。"
    else
        echo "当前规则未永久化保存。"
    fi
}

# 添加规则
add_rules() {
    # 默认值
    local default_start_port=34553
    local default_end_port=34700
    local default_target_port=34552

    # 提示用户输入端口，若没有输入则使用默认值
    echo "请输入起始端口 (默认值：$default_start_port)："
    read start_port
    start_port=${start_port:-$default_start_port}

    echo "请输入结束端口 (默认值：$default_end_port)："
    read end_port
    end_port=${end_port:-$default_end_port}

    echo "请输入目标端口 (默认值：$default_target_port)："
    read target_port
    target_port=${target_port:-$default_target_port}

    echo "当前网络接口信息："
    ip address
    echo "请输入网卡名称："
    read interface

    sudo iptables -t nat -A PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port
    sudo ip6tables -t nat -A PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port

    echo "$interface $start_port $end_port $target_port" > /tmp/iptables_rule_info
    echo "规则已添加。"

    save_rules
}

# 删除规则
delete_rules() {
    if [ -f /tmp/iptables_rule_info ]; then
        read interface start_port end_port target_port < /tmp/iptables_rule_info
        sudo iptables -t nat -D PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port
        sudo ip6tables -t nat -D PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port
        rm /tmp/iptables_rule_info
        echo "规则已删除。"

        save_rules
    else
        echo "没有找到之前添加的规则。"
    fi
}

# 菜单
while true; do
    # 检查并安装sudo
    install_sudo

    echo "请选择操作："
    echo "1. 安装iptables规则"
    echo "2. 删除iptables规则"
    echo "3. 检查规则是否永久化保存"
    echo "4. 退出"

    read choice

    case $choice in
        1)
            install_iptables_persistent
            add_rules
            ;;
        2)
            delete_rules
            ;;
        3)
            check_persistent_rules
            ;;
        4)
            exit 0
            ;;
        *)
            echo "无效的选择，请重试。"
            ;;
    esac
done
