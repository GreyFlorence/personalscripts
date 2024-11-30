#!/bin/bash

# 函数：检查并安装iptables-persistent
install_iptables_persistent() {
    if ! dpkg -l | grep -qw iptables-persistent; then
        echo "正在安装iptables-persistent..."
        apt-get update
        apt-get install -y iptables-persistent sudo
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
    echo "请输入起始端口："
    read start_port
    echo "请输入结束端口："
    read end_port
    echo "请输入目标端口："
    read target_port

    echo "当前网络接口信息："
    ip address
    echo "请输入网卡名称："
    read interface

    sudo iptables -t nat -A PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port
    sudo ip6tables -t nat -A PREROUTING -i $interface -p udp --dport $start_port:$end_port -j REDIRECT --to-ports $target_port

    echo "规则已添加。"

    save_rules
}

# 菜单
while true; do
	echo "删除规则请手动在/etc/iptables/rules.v4与/etc/iptables/rules.v6文件中删除"
    echo "请选择操作："
    echo "1. 安装iptables规则"
    echo "2. 检查规则是否永久化保存"
    echo "3. 退出"

    read choice

    case $choice in
        1)
            install_iptables_persistent
            add_rules
            ;;
        2)
            check_persistent_rules
            ;;
        3)
            exit 0
            ;;
        *)
            echo "无效的选择，请重试。"
            ;;
    esac
done
