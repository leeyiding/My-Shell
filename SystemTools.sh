#!/bin/bash

#################################################################################################
#           Name：SystemTools                                                                   #
#           Author: leeyiding                                                                   #
#           Data: 2020.03.05                                                                    #
#           Des: This is a system tools can help you Install and Confige some useful tools      #
#           Warning: Only support CentOS7 | Ubuntu14.04/16.04               #
#           Version: 1.0                                                                        #
#################################################################################################

red='\033[0;31m'green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

if [[ $EUID -ne 0 ]];then
    echo -e "[${red}Error${plain}] This script must be run as root!"
    exit 1
fi

disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/
selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinu
x/config
        setenforce 0
    fi
}

check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        package_manager="yum"
    # elif grep -Eqi "debian|raspbian" /etc/issue; then
    #     release="debian"
    #     package_manager="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        package_manager="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        package_manager="yum"
    # elif grep -Eqi "debian|raspbian" /proc/version; then
    #     release="debian"
    #     package_manager="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        package_manager="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        package_manager="yum"
    fi
}

install_docker() {
    check_sys
    if [ $1 = "default" -o $1 = "1" ];then
        if [ release = "centos" ];then
            yum install -y yum-utils device-mapper-persistent-data lvm2
            yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
            yum makecache fast
            yum -y install docker-ce
        elif [ release = "ubuntu" ];then
            apt-get update
            apt-get -y install apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
            add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
            apt-get -y update
            apt-get -y install docker-ce
        fi
        systemctl start docker
        systemctl enable docker
    fi

    if [ $1 = "default" -o $1 = "2" ];then
        mkdir -p /etc/docker
        tee /etc/docker/daemon.json <<-'EOF'
        {
        "registry-mirrors": ["https://7vqnfgso.mirror.aliyuncs.com"]
        }
EOF
        systemctl daemon-reload
        systemctl restart docker
    fi

    if [ $1 = "default" -o $1 = "3" ];then
        curl -L https://github.com/docker/compose/releases/download/1.24.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
        if [ $? -ne 0 ];then
            echo "安装Docker-Compose失败，请检查网络"
            exit 1
        fi
        chmod +x /usr/local/bin/docker-compose
        echo "安装成功"
    fi    
}

docker_menu() {
    while true
    do
        clear
        cat <<-EOF
-------------- Install Docker --------------
        1. 安装Docker-CE
        2. 更换Docker镜像源
        3. 安装Docker-Compose
        4. 返回主菜单
--------------------------------------------
EOF
        read -p "请选择菜单[1-4]，默认为1-3: " docker_option
        if [[ -z $docker_option ]];then
            install_docker default
            break
        elif [ $docker_option = "1" ];then
            install_docker 1
            break
        elif [ $docker_option = "2" ];then
            install_docker 2
            break
        elif [ $docker_option = "3" ];then
            install_docker 3
            break
        elif [ $docker_option = "4" ];then
            main_menu
        elif [[ $docker_option != [1-3] ]];then
            docker_menu
        fi
    done
}

install_baota() {
    check_sys
    if [ $1 = "official" ];then
        if [ release = "centos" ];then
            yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
        elif [ release = "ubuntu" ];then
            wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh
        fi
        if [ $? -eq 0 ];then
            echo "安装成功，请前往放行防火墙888,3306,8888端口"
        else
            echo "安装失败"
        fi
    elif [ $1 = "docker" ];then
        which docker &>/dev/null
        if [ $? -ne 0 ];then
            install_docker 1
        fi     
        docker run -tid --name baota -p 80:80 -p 443:443 -p 8888:8888 -p 888:888 --privileged=true --shm-size=1g --restart always -v ~/wwwroot:/www/wwwroot pch18/baota
        if [ $? -eq 0 ];then
            echo "安装成功,请前往放行防火墙888,3306,8888端口"
            echo "登陆地址：http://IP:8888"
            echo "初始账号：username"
            echo "初始密码：password"
        fi           
    fi
}

baota_menu() {
    while true
    do
        clear
        cat <<-EOF
-------------- Install Baota ---------------
        1. 安装官方版本
        2. 安装Docker版本
        3. 返回主菜单
--------------------------------------------
EOF
        read -p "请选择菜单[1-3]: " baota_option
        if [ $baota_option = "1" ];then
            install_baota official
            break
        elif [ $baota_option = "2" ];then
            install_docker docker
            break
        elif [ $baota_option = "3" ];then
            main_menu
        elif [[ $baota_option != [1-3] ]];then
            baota_menu
        fi
    done
}

install_ssr() {
    wget --no-check-certificate -O shadowsocks-all.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-all.sh
    chmod +x shadowsocks-all.sh
    clear
    ./shadowsocks-all.sh 2>&1 | tee shadowsocks-all.log
}

change_repo() {
    check_sys
    if [ release = "centos" ];then
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    elif [ release = "ubuntu" ];then
        sed -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list
    fi
    if [ $? -eq 0 ];then
        echo "换源成功"
    else
        echo "换源失败"
    fi
}

main_menu() {
    while true
    do
        clear
        cat <<-EOF
---------------System Tools---------------
        1. 安装Docker
        2. 安装宝塔面板
        3. 安装ShadowSocksR
        4. 切换镜像源
        5. 退出System Tools
------------------------------------------
EOF
        read -p "请选择你要安装的工具[1-5]: " option
        case $option in 
            1)
                docker_menu
                break
                ;;
            2)
                baota_menu
                break
                ;;
            3)
                install_ssr
                break            
                ;;
            4)
                change_repo
                break
                ;;
            5)
                exit 0
        esac
    done
}
main_menu