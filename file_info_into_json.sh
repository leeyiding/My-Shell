#!/bin/bash
#Author: leeyiding
#Date: 2020.03.01
#Des: 监视文件夹，将新增文件的名称、创建时间等信息写入json文件
#Version: 1.0

#定义变量
work_path=/root/wwwroot/test/test_road
pid_path=/tmp/my_sh.pid
old_file_path=/root/wwwroot/test/old_file.txt
json_path=/root/wwwroot/test/data.json
uri_prefix=http://39.106.70.75/test_road/
source=http://39.106.70.75

#切换工作目录
cd $work_path

#检查进程唯一性
if [ -f $pid_path ];then
    kill $(cat $pid_path) > /dev/null
    rm -rf $pid_path
fi
echo $$ > $pid_path

#判断是否安装jo
which jo &>/dev/null
if [ $? -ne 0 ];then
    yum install -y git automake autoconf &>/dev/null
    if [ $? -ne 0 ];then
        echo "Error: Please check your netwwork or yum repository"
        exit 1
    fi
    git clone git://github.com/jpmens/jo.git &>/dev/null
    if [ $? -ne 0];then
        echo "Error: Can not access to GitHub, Please check your network"
        exit 1
    fi
    cd jo
    autoreconf -i &>/dev/null
    ./configure &>/dev/null && make check &>/dev/null && make install $>/dev/null
    if [ $? -ne 0 ];then
        echo "Error: Failed to install jo, Please go to https://github.com/jpmens/jo to install jo manually."
        exit 1
    fi
    cd ../ && rm -rf jo
fi

#定义函数
sync_data() {
    sed -ri 's/(" }$)/\1,/' $json_path
    date_yMd=`stat $1 | grep Modify | awk '{print $2}'`
    date_hms=`stat $1 | grep Modify | awk '{print $3}' | awk -F '.' '{print $1}'`
    date=${date_yMd}T${date_hms}.000Z
    pre_json=`jo -p uri=${uri_prefix}$1 created_at=$date source=$source`
    json=`echo $pre_json | sed -r 's/(")/\\\&/g'`
    sed -ri "/]/i $json" $json_path
    sed -ri 's/(^\{.")/\t\1/' $json_path
    echo $1 >> $old_file_path
}

if [ ! -f $json_path -o ! -f $old_file_path ];then
    rm -f $json_path $old_file_path
    jo -p data=$(jo -a n) | sed -r '/("n")/ d' >> $json_path
    for file_name in `ls`
    do
        sync_data $file_name
    done
fi

while true
do
    for new_file in `ls`
    do 
        grep -q $new_file $old_file_path
        if [ $? -eq 0 ];then
            continue
        else
            sync_data $new_file
        fi
    done
    sleep 1
done
