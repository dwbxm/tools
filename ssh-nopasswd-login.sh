#!/bin/bash

#description:批量部署SSH免密登录脚本
#host.txt 格式:
#ip user passwd
#执行： ssh-nopasswr-login host.txt


E_ERROR=65

#传参检测
if [ $# -ne 1 ]
then 
    echo -e "Usage:$0 ip_list_file "
    exit E_ERROR
fi

#文件检测
if [ ! -f "$1" ]
then
    echo -e "IP_List_File $1文件异常,请检查内容"
    exit E_ERROR
fi 

#初始化
ip_list_file=$1
#从文本读取值初始化变量
ip_address=`awk '{print $1}' $ip_list_file)`
username=(`awk '{print $2}' $ip_list_file`)
password=(`awk '{print $3}' $ip_list_file`)

#安装软件检测及部署环境配置
echo -e "》》》开始检测依赖的必须组件是否安装》》》\n"
if [ `rpm -qa | grep "expect" &> /dev/null;echo $?` -ne 0 ]
then
    echo -e "未安装必须组件Expect,开始执行安装,请稍等..."
    ( yum install -y expect &> /dev/null && echo -e ">Expect安装完成!" ) || ( echo -e "部署必须组件Expect失败,请检查Yum配置" && exit E_ERROR )
elif [ $(rpm -qa | grep "openssl" &> /dev/null;echo $?) -ne 0 ]
then
    ( yum install -y openssh &> /dev/null && echo -e ">Openssh安装完成!" ) || ( echo -e "部署必须组件Openssh失败,请检查Yum配置" && exit E_ERROR )
elif [ `rpm -qa | grep "openssh-clients" &> /dev/null;echo $?` -ne 0 ]
then
    ( yum install -y openssh-clients &> /dev/null && echo -e ">Openssh-clients安装完成!" ) || ( echo -e "部署必须组件Openssh-clients失败,请检查Yum配置" && exit E_ERROR )
else
    echo -e ">必须组件Expect已安装"
    echo -e ">必须组件Openssh已安装"
    echo -e ">必须组件Openssh-clients已安装"
fi


#打印菜单
echo -e "\n===============================================" 
echo -e "该脚本可以实现批量部署和删除SSH免密配置"   
echo -e "===============================================" 
    while :
    do
    echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" 
    echo -e "1. 配置SHH免密登录"
    echo -e "2. 取消SHH免密配置"
    echo -e "3. 退出程序"
    
    #功能控制及实现
    read -p "请输入序号>>> " nu
    if [[ "$nu" == "3" ]]
    then
        #退出程序
        echo -e "\n###!!!感谢使用,再见!!!###"
        exit 0
    elif [[ "$nu" == "1" ]]
    then    
        echo "开始推送"
        #检测公钥文件是否存在,不存在则生成
        if [ ! -e "$HOME/.ssh/id_rsa.pub" ];then
            ssh-keygen -t rsa -P '' -f $HOME/.ssh/id_rsa
        else
            echo -e "》》》已创建公钥文件,开始向远端服务器推送公钥》》》"
        fi

        #循环控制
        count=`grep -v '^$' $ip_list_file | wc -l `
        for (( i=0;i<$count;i++ ))
        do
            #echo -e "${ip_address[$i]}\t${username[$i]}\t${password[$i]}"
            #自动化交互实现推送ssh公钥
            /usr/bin/expect<<-EOF
            spawn ssh-copy-id -i $HOME/.ssh/id_rsa.pub ${username[$i]}@${ip_address[$i]}
            expect {
            "*yes/no"    { send "yes\r";exp_continue }
            "*password"  { send "${password[$i]}\r" }
        }
        expect eof
EOF
        done
        echo -e "--------------------------------------------------------------------------------------"
        echo -e "###推送完成,尝试免密登录###"
        #推送公钥成功免密结果通知
        for (( i=0;i<$count;i++ ))
        do
            /usr/bin/expect<<-EOF
            spawn ssh ${username[$i]}@${ip_address[$i]}
            expect "*]#"
            send "echo "##登录成功##"\r"
            expect "*]#"
            send "exit\r"
EOF
        done
        echo -e "-------------------------------------------"
        echo -e "已完成SHH免密配置,请尝试SHH登录远端主机确认"

    elif [[ "$nu" == "2" ]]
    then
        #自动化交互实现删除配置免密的远程主机上的authorized_keys
        count=`grep -v '^$' $ip_list_file | wc -l `
        for (( i=0;i<$count;i++ ))
        do
        /usr/bin/expect<<-EOF
        spawn ssh ${username[$i]}@${ip_address[$i]}
        expect "*]#"    
        send "rm -f /root/.ssh/authorized_keys 2> /dev/null\r"
        expect "*]#"
        send "exit\r"
EOF
        done 
        echo -e "-------------------------------------------"
        echo -e "已取消SHH免密配置,请尝试SHH登录远端主机确认"

    else
        echo -e "\033[41;37m 非法输入,请检查输入!!! \033[0m"
    fi
done


