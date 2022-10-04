#!/bin/bash
CONF_EXAMPLE="
[Default]
Mode: uni
User: ansible
ListentDurationInMinutes: 100
[Block1]
ListentDurationInMinutes: 10
User: root
TCPPorts:1001-1010,2000,3031-3040
UDPPorts:4001-4010,5000,6011-6020
TestersIPs:
192.168.2.196
ListenersIPs:
192.168.1.2
192.168.1.3-192.168.1.220
192.168.1.224
[block 2]
Mode:bi
TCPPorts:1001-1010,2000,3031-3040
IPs:
192.168.1.2
192.168.1.3-192.168.1.40
192.168.1.44
192.168.1.50-192.168.1.55"
# log error function
Raise_Error () {
    echo -en "\t\033[0;31mError\033[0m:\n\t"
    case $1 in
        1)
            echo "configuration file not specified .. file format as following\n#####${CONF_EXAMPLE}\n#####"
            ;;
        2)
            echo -e "\tSystem shell is not supported"
            ;;
        3)
            echo -e "\tDuplicate Block Name in ${BlockName}" 
            ;;
        4)
            echo -e "\tDuplicate Attribute Key in ${BlockName}=>${BlockAttributeName}" 
            ;;
        5)
            echo -e "\tInvalid Attribute $2 Key in ${BlockName}=>${Mode} \n\t\t\t$3" 
            ;;
        6)
            echo -e "\tAttribute $2 is Missing  in ${BlockName}\n\t\t\t$3"
            ;;
        7)
            echo -e "\tInvalid Attribute $2 Value in ${BlockName}\n\t\t\t$3"
            ;;
        8)
            echo -e "\tCan not reach $2 ${BlockName}\n\t\t\t$3" 
            ;;
        9)
            echo -e "\tCan not Access $2  ${BlockName}\n\t\t\t$3" 
            ;;
        10)
            echo -e  "\tLack of Authorization  on $2 ${BlockName}\n\t\t\t$3" 
            ;;
    esac
    exit $1
}

####
unset ConfFileName ConfFileContent BlocksNames ExecutionDate LOCALSAVE CONFPATH
ConfFileContent=$(egrep -v '^$|^#' $1|tr -d ' '|sed 's/\[/EOB\n\[/g'|sed '1d'|sed -e '$a\EOB')
ConfFileName=$(echo ${1##*/}|tr -d ' '|sed 's/.conf//')
BlocksNames=$(echo "${ConfFileContent}" |grep '\['|tr -d '['|tr -d ']') 
ExecutionDate=$(date  +"%Y_%m_%d_%H_%M_%S")
LOCALSAVE="${HOME}/CommsMatrix/${ConfFileName}-${ExecutionDate}"
CONFPATH="${LOCALSAVE}/${ConfFileName}.conf"
SSH_PORT=22
Listener_UDPScript="#!/usr/bin/python
from socket import socket,AF_INET,SOCK_DGRAM,SO_REUSEADDR,SOL_SOCKET
from time import sleep,ctime
import sys
if len(sys.argv)>2:
    localIP = sys.argv[1]
    localPort = int(sys.argv[2])
bufSize = 1500
sock = socket(family=AF_INET, type=SOCK_DGRAM)
sock.setsockopt(SOL_SOCKET,SO_REUSEADDR, 1)
sock.bind((localIP, localPort))
while True:
    message, ipport = sock.recvfrom(bufSize)"
Listener_TCPScript="#!/usr/bin/python
import socket
import sys
if len(sys.argv)>2:
    localIP = sys.argv[1]
    localPort = int(sys.argv[2])
bufSize = 1500
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind((localIP, localPort))
sock.listen(1)
conn, addr = sock.accept()
while True:
    data = conn.recv(bufSize)
    conn.sendall(data)"

####functions to be called later#####
#1-Validation functions
Validate_Ports() {
	for Ports in $(echo $1|tr ',' ' ')
    do
        echo ${Ports}|grep -q '-'
        exit_status=$?
        if [ ${exit_status} -eq 0 ]
        then
            Start_Port=$(echo ${Ports}|cut -d '-' -f1 )
            End_Port=$(echo ${Ports}|cut -d '-' -f2 )
            if ! [[ ${Start_Port} == ?(-)+([0-9]) ]] 
            then
                Raise_Error 7 $2 "Start port ${Start_Port} is not integer "
            elif ! [[ ${End_Port} == ?(-)+([0-9]) ]] 
            then
                Raise_Error 7 $2 "End port ${End_Port} is not integer "
            elif [ ${Start_Port} -lt 0 -o ${Start_Port} -gt 65536 -o ${End_Port} -lt 0 -o ${End_Port} -gt 65536 ]
            then
                Raise_Error 7 $2 "Port Range is 0=>65536"
            elif [ ${Start_Port} -gt ${End_Port} ]
            then
                Raise_Error 7 $2 "Start port ${Start_Port} is greater than End port ${End_Port}"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            fi
        else
            if ! [[ ${Ports} == ?(-)+([0-9]) ]] 
            then
                Raise_Error 7 $2 "port ${Ports} is not intger"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            elif [ ${Ports} -lt 0 -o ${Ports} -gt 65536 ]
            then 
                Raise_Error 7 $2 "Port Range is 0=>65536"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            fi
        fi
    done
    echo -e "\t\tPort Range  ${Ports} : ok"|tee -a ${LOCALSAVE}/${ConfFileName}.log
}
Validate_IPS () {
	for IPs in $(echo $1|tr ',' ' ')
	do
		echo ${IPs}|grep -q '-'
        exit_status=$?
		if [ ${exit_status} -eq 0 ]
		then
            Start_IP=$(echo ${IPs}|cut -d '-' -f1 )         &>/dev/null
            End_IP=$(echo ${IPs}|cut -d '-' -f2 )           &>/dev/null
            Start_IP_OCT1=$(echo ${Start_IP}|cut -d'.' -f1) &>/dev/null
            Start_IP_OCT2=$(echo ${Start_IP}|cut -d'.' -f2) &>/dev/null
            Start_IP_OCT3=$(echo ${Start_IP}|cut -d'.' -f3) &>/dev/null
            Start_IP_OCT4=$(echo ${Start_IP}|cut -d'.' -f4) &>/dev/null
            End_IP_OCT1=$(echo ${End_IP}|cut -d'.' -f1)     &>/dev/null
            End_IP_OCT2=$(echo ${End_IP}|cut -d'.' -f2)     &>/dev/null
            End_IP_OCT3=$(echo ${End_IP}|cut -d'.' -f3)     &>/dev/null
            End_IP_OCT4=$(echo ${End_IP}|cut -d'.' -f4)     &>/dev/null
            for IP in ${Start_IP} ${End_IP}
            do
                if ! [[ ${IP} =~  ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
                then
                    Raise_Error 7 $2 "Ip ${IP} bad format"|tee -a ${LOCALSAVE}/${ConfFileName}.log
                fi
            done
            if [ ${Start_IP_OCT1} -ne ${End_IP_OCT1} -o ${Start_IP_OCT2} -ne ${End_IP_OCT2} -o ${Start_IP_OCT3} -ne ${End_IP_OCT3} ]
            then
                Raise_Error 7 $2 "Script support /24 range only,specified value ${Start_IP}=>${End_IP}"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            elif [ ${Start_IP_OCT4} -gt ${End_IP_OCT4} ]
            then 
                Raise_Error 7 $2 "Range ${Start_IP}=>${End_IP} Invalid"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            fi
		else 
			if ! [[ ${IPs} =~  ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
			then
				Raise_Error 7 $2 "Ip ${IPs} bad format"|tee -a ${LOCALSAVE}/${ConfFileName}.log
			fi
		fi
	done
    echo -e "\t\tIP Range ${1}: ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
}
Validate_ListentDurationInMinutes () {
			if [[ $1 == ?(-)+([0-9]) ]] 
			then
				if [ $1 -le 0 ]
				then
                    Raise_Error 7 $2 "can not be zero or netgative"|tee -a ${LOCALSAVE}/${ConfFileName}.log
                else
                    echo -e "\t\tListenDuration $1 : ok "
				fi
			else 
                    Raise_Error 7 $2 "is not an integer"|tee -a ${LOCALSAVE}/${ConfFileName}.log
			fi
}
Validate_Access(){
    echo -e "\t\t${1} Access/Autorization:" | tee -a ${LOCALSAVE}/${ConfFileName}.log
    nc -w 2 -z ${1} ${SSH_PORT} 
    exit_status=$?
    if [ ${exit_status} -ne 0 ]  
    then
        Raise_Error 8 ${1} -e "\tssh@${1} : down" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    else
        echo -e -e "\t\t\tssh@${1} : ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    fi
    ssh -q -p ${SSH_PORT}  -o PasswordAuthentication=no -o StrictHostKeyChecking=no ${User}@${1} sudo -vn &> /dev/null
    exit_status=$?
    if [ ${exit_status} -eq 0 ]
    then
        echo -e "\t\t\t${1} pubkey/sudo no passwd : ok "|tee -a ${LOCALSAVE}/${ConfFileName}.log 
    elif [ ${exit_status} -eq 1 ]
    then
        Raise_Error 10 ${1} "\t\t:${User} is not sudoer nopasswd on remote server"|tee -a ${LOCALSAVE}/${ConfFileName}.log
    elif [ ${exit_status} -eq 255 ]
    then
        Raise_Error 9 ${1} "\t\t${1}:${USER} publickey is not authorized on ${User}@${1}"|tee -a ${LOCALSAVE}/${ConfFileName}.log
    elif [ ${exit_status} -ne 0 ]
    then
        Raise_Error 10 ${1} "\t\t${1}:ssh geneeric  Error"|tee -a ${LOCALSAVE}/${ConfFileName}.log
    fi
}
Validate_Install_Dependencies () {
    [ $1 = localhost ] &&    echo -e "\t${1} Dependencies: " |  tee -a ${LOCALSAVE}/${ConfFileName}.log ||     echo -e "\t\t${1} Dependencies:" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    if  [ -e /bin/dash ] 
    then
        diff /bin/sh /bin/dash &> /dev/null
        exit_status=$?
        if [ $? -eq 0 ]
        then
            sudo ln -sf /bin/bash /bin/sh && echo -e "\t\t\tatd service default shell changed from sh to bash on " |tee -a ${LOCALSAVE}/${ConfFileName}.log
        else
            echo -e "\t\t\tatd service default shell is bash no change needed" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        fi
    else
            echo -e "\t\t\tatd service default shell is bash no change needed" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    fi
    echo -e "\t\t\tchecking for netcat/atd packages" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    for PackageManager in "yum" "apt-get" 
    do
        for Package in "nc" "at"
        do
            which ${PackageManager} &> /dev/null
            exit_status=$?
            if [ $exit_status -eq 0 ]
            then
                which ${Package} &> /dev/null 
                exit_status=$?
                if [ $? -eq 0 ]
                then
                    echo -e "\t\t\t\tpackage ${Package} is already installed" |tee -a ${LOCALSAVE}/${ConfFileName}.log
                else 
                    sudo ${PackageManager} install -y -q  ${Package}  && echo -e "\t\t\t\t${Package} is not installed ,installing .." |tee -a ${LOCALSAVE}/${ConfFileName}.log
                fi
                [ ${Package} = "at" ] &&  sudo  systemctl start atd &> /dev/null
            fi
        done
    done
}


#3-Expand ips function and also exclude ips that are unreachable or is not root or sudoer nopasswd on it , logged
expand_ips() {   
    unset Expanded_IPs
    for IPRange in $(echo $1|cut -d ':' -f2 |tr ',' ' ')
    do
        echo ${IPRange}|grep -q '-'
        exit_status=$?
        if [ ${exit_status} -eq 0 ]
        then
                Start_IP=$(echo ${IPRange}|cut -d '-' -f1 )
                End_IP=$(echo ${IPRange}|cut -d '-' -f2 )
                Start_IP_OCT1=$(echo ${Start_IP}|cut -d'.' -f1)
                Start_IP_OCT2=$(echo ${Start_IP}|cut -d'.' -f2)
                Start_IP_OCT3=$(echo ${Start_IP}|cut -d'.' -f3)
                Start_IP_OCT4=$(echo ${Start_IP}|cut -d'.' -f4)
                End_IP_OCT1=$(echo ${End_IP}|cut -d'.' -f1)
                End_IP_OCT2=$(echo ${End_IP}|cut -d'.' -f2)
                End_IP_OCT3=$(echo ${End_IP}|cut -d'.' -f3)
                End_IP_OCT4=$(echo ${End_IP}|cut -d'.' -f4)
                for IP in $(seq ${Start_IP_OCT4} ${End_IP_OCT4})
                do
                    Expanded_IPs="${Expanded_IPs} ${Start_IP_OCT1}.${Start_IP_OCT2}.${Start_IP_OCT3}.${IP}"
                done
        else
                    Expanded_IPs="${Expanded_IPs} ${IPRange}"
        fi     
    done
    IPName=$(echo $1|cut -d ':' -f1)
    if [ ${IPName} = ListenersIPs ]
    then
        Expanded_ListenersIPs=${Expanded_IPs}
    elif [ ${IPName} = TestersIPs ]
    then
        Expanded_TestersIPs=${Expanded_IPs} 
    fi
}
#4-Generate script for listeners/testers/report gathering
generate_listeners () {
        [ -z ${TCPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-tcp.sh
        #!/bin/bash
        mkdir -p ${REMOTESAVE}/${BlockName}-LocalLogs
        FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
        if [ \${FWStatus} = active ] 
        then
            echo -e "Firewall on ${ListenerIP} was up: stop for ${ListentDurationInMinutes} Minutes"  &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
            sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
        else
            echo -e "Firewall on ${ListenerIP} was down: no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
        fi
        if [ -e /tmp/TCP-Listener.py ] 
        then
            echo -e "TCP-Listener.py is already exist on ${ListenerIP}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
        else
            echo -e "TCP-Listener.py is not exist on ${ListenerIP} will be creted on /tmp/TCP-Listener.py " &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
            echo "${Listener_TCPScript}" >> /tmp/TCP-Listener.py
        fi
        echo -e "Start Listening on tcp Ports ${ListenerIP}:${TCPPorts} " &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
        for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
        do
            echo "\${Ports}"|grep -q '-'
            exit_status=\$?
            if [ \${exit_status} -eq 0 ] 
            then
                echo -e "start Listening to \{Ports} tcp range" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                for Port in \$(seq \${Start_Port} \${End_Port})
                do
                    nc -w 2 -z ${ListenerIP} \${Port}
                    exit_status=\$?
                    if [ \${exit_status} -ne 0 ]
                    then
                        echo -e "tcp ${ListenerIP}:\${Port} was down , bringing it up for ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                        #echo "nc -4kl ${ListenerIP} \${Port}"|at now
                        #PID=\$( pgrep -la nc|grep "${ListenerIP} \${Port}"|cut -d' ' -f1)
                        #while [ -z \${PID} ] ; do   PID=\$( pgrep -la nc|grep "${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                        #echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                        echo "python /tmp/TCP-Listener.py ${ListenerIP} \${Port}"|at now
                        unset PID
                        PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1)
                        while [ -z \${PID} ] ; do  PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                        echo -e "port ${ListenerIP}:\${Port} tcp is running on \${PID} will be killed after ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                        echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    else
                        echo "Port \${Port} on ${ListenerIP} was up , no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                    fi
                done
            else
                nc -w 2 -z ${ListenerIP} \${Ports}
                exit_status=\$?
                if [ \${exit_status} -ne 0 ]
                then
                    echo -e "tcp ${ListenerIP}:\${Ports} was down , bringing it up for ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                    #echo "nc -4kl ${ListenerIP} \${Ports}"|at now
                    #PID=\$( pgrep -la nc|grep "${ListenerIP} \${Ports}"|cut -d' ' -f1)
                    #while [ -z \${PID} ] ; do   PID=\$( pgrep -la nc|grep "${ListenerIP} \${Ports}"|cut -d' ' -f1) ; done
                    #echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    echo "python /tmp/TCP-Listener.py ${ListenerIP} \${Ports}"|at now
                    unset PID
                    PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1)
                    while [ -z \${PID} ] 
                    do
                        PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1)
                    done
                    echo -e "port ${ListenerIP}:\${Ports} tcp is running on \${PID} will be killed after ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                    echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                else
                    echo "Port \${Ports} on ${ListenerIP} was up , no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                fi
            fi
        done
EOF
            [ -z ${UDPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-udp.sh
            #!/bin/bash
            mkdir -p ${REMOTESAVE}/${BlockName}-LocalLogs
            FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            if [ \${FWStatus} = active ]
            then
                echo -e "Firewall on ${ListenerIP} was up: stop for ${ListentDurationInMinutes} Minutes"  &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            else
                echo -e "Firewall on ${ListenerIP} was down: no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
            fi
            if [ -e /tmp/UDP-Listener.py ] 
            then
                echo -e "UDP-Listener.py is already exist on ${ListenerIP}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
            else
                echo -e "UDP-Listener.py is not exist on ${ListenerIP} will be creted on /tmp/UDP-Listener.py " &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                echo "${Listener_UDPScript}" >> /tmp/UDP-Listener.py
            fi
            echo -e "Start Listening on udp Ports ${ListenerIP}:${UDPPorts} " &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
            for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
            do
                echo "\${Ports}"|grep -q '-'
                exit_status=\$?
                if [ \${exit_status} -eq 0 ] 
                then
                    echo -e "start Listening to \{Ports} udp range" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                    Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                    End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                    for Port in \$(seq \${Start_Port} \${End_Port})
                    do
                        nc -uz -w 2 ${ListenerIP} \${Port}
                        exit_status=\$?
                        if [ \${exit_status} -ne 0 ]
                        then
                            echo -e "udp ${ListenerIP}:\${Port} was down , bringing it up for ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                            echo "python /tmp/UDP-Listener.py ${ListenerIP} \${Port}"|at now
                            unset PID
                            PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1)
                            while [ -z \${PID} ] ;do PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                            echo -e "port ${ListenerIP}:\${Port} udp is running on \${PID} will be killed after ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                            echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                        else
                            echo -e "udp ${ListenerIP}:\${Port} was up , no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                        fi
                    done
                else
                    nc -uz -w 2 ${ListenerIP} \${Ports}
                    exit_status=\$?
                    if [ \${exit_status} -ne 0 ]
                    then
                        echo -e "udp ${ListenerIP}:\${Ports} was down , bringing it up for ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                        echo "python /tmp/UDP-Listener.py ${ListenerIP} \${Ports}"|at now
                        unset PID
                        PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1)
                        while [ -z \${PID} ]
                        do
                            echo -e "port ${ListenerIP}:\${Ports} udp is running on \${PID} will be killed after ${ListentDurationInMinutes} Minutes" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                            PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1)
                        done
                        echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    else
                        echo -e "udp ${ListenerIP}:\${Ports} was up , no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                    fi
                fi
            done
EOF
}
generate_testers () {
                [ -z ${TCPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-tcp.sh
                #!/bin/bash
                mkdir -p ${REMOTESAVE}/${BlockName}-{LocalReports,LocalLogs}
                touch ${REMOTESAVE}/${BlockName}-LocalLogs/ActualDoneList
                echo -e "Start Testing  tcp on ${ListenerIP}:${TCPPorts}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
                do
                    echo -e "Start Testing  tcp on ${TesterIP}=>${ListenerIP}:\${Ports}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                    echo "\${Ports}"|grep -q '-'
                    exit_status=\$?
                    if [ \${exit_status} -eq 0 ] 
                    then
                        Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                        End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                        for retry in \$(seq 1 ${ListentDurationInMinutes})
                        do
                            nc -z -w 2 ${ListenerIP} \${End_Port} &> /dev/null
                            exit_status=\$?
                            if [ \${exit_status} -eq 0 ]
                            then 
                                echo -e "last port in range tcp range \${Start_Port}=>\${End_Port} is up , start testing the whole range"     &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                                for Port in \$(seq \${Start_Port} \${End_Port}) ; do echo -e "testing tcp ${TesterIP}=>${ListenerIP}:\${Port}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log ;nc -vz -w 2 ${ListenerIP} \${Port}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt ;done
                                break
                            else
                                echo -e "last port on udp range \${Ports} still down sleep for \${retry} seconds" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                                sleep \${retry}
                            fi
                        done
                        [ \${retry} -eq ${ListentDurationInMinutes} ] && echo -e "last Port in tcp port range \${Ports} is down for long time , giving up the whole range" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                    else
                        echo -e "testing tcp ${TesterIP}=>${ListenerIP}:\${Ports}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                        nc -vz -w 2 ${ListenerIP} \${Ports}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt
                    fi
                done
                echo  "${TesterIP}-${ListenerIP}-tcp" >> ${REMOTESAVE}/${BlockName}-LocalLogs/ActualDoneList
EOF
            [ -z ${UDPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-udp.sh
            #!/bin/bash
            mkdir -p ${REMOTESAVE}/${BlockName}-LocalReports
            touch ${REMOTESAVE}/${BlockName}-LocalLogs/ActualDoneList
            echo -e "Start Testing  udp on ${ListenerIP}:${UDPPorts}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
            for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
            do
                echo "\${Ports}"|grep -q '-'
                exit_status=\$?
                if [ \${exit_status} -eq 0 ] 
                then
                    echo -e "Start Testing  udp on ${TesterIP}=>${ListenerIP}:\${Ports}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
                    Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                    End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                    for retry in \$(seq 1 ${ListentDurationInMinutes})
                    do    
                        nc -uz -w 2 ${ListenerIP} \${End_Port} &> /dev/null
                        exit_status=\$?
                        if [ \${exit_status} -eq 0 ]
                        then
                            echo -e "last port in range \${Ports} is up , start testing the whole range"     &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
                            for Port in \$(seq \${Start_Port} \${End_Port}) ;do echo -e "testing udp ${TesterIP}=>${ListenerIP}:\${Port}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log ;nc -vuz -w 2 ${ListenerIP} \${Port}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt ; done
                            break
                        else
                            echo -e "last port on udp range \${Ports} still down sleep for \${retry} seconds" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
                            sleep \$retry
                        fi
                    done
                    [ \${retry} -eq ${ListentDurationInMinutes} ] && echo -e "last Port in udp port range \${Ports} is down for long time , giving up the whole range" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
                else
                    echo "Test udp ${TesterIP}=>${ListenerIP}:\${Ports}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
                    nc -vuz -w 2 ${ListenerIP} \${Ports}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt
                fi
            done
            echo  "${TesterIP}-${ListenerIP}-udp" >> ${REMOTESAVE}/${BlockName}-LocalLogs/ActualDoneList
EOF
}
Generate_Collect_Reports () {
cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}.sh
until [ "\$(sort -n ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ExpectedDoneList)" = "\$(sort -n ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ActualDoneList)" ]
do
    sleep $(expr ${ListentDurationInMinutes} \* 6 ) 
    echo -e "Waiting for ${BlockName} => ${TesterIP} to finish testing sleep for $(expr ${ListentDurationInMinutes} \* 6 ) seconds  " >> ${LOCALSAVE}/${ConfFileName}.log
    scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalLogs/ActualDoneList ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ActualDoneList 
done
scp -rP ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalReports ${LOCALSAVE}/${BlockName}-Reports/${TesterIP}
echo -e "${BlockName}=>${TesterIP} finished testing reports saved to ${LOCALSAVE}/${BlockName}-Reports/${TesterIP}" >>  ${LOCALSAVE}/${ConfFileName}.log
echo -e "${BlockName}-${TesterIP}" >> ${LOCALSAVE}/${BlockName}-Reports/ActualCollectedReports
EOF
}
Generate_Collect_Logs () {
cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/logs_gathering.sh
until [ "\$(sort -n ${LOCALSAVE}/${BlockName}-Reports/ActualCollectedReports)" = "\$(sort -n ${LOCALSAVE}/${BlockName}-Reports/ExpectedCollectedReports )" ]
do
    sleep $(expr ${ListentDurationInMinutes} \* 6 ) 
    echo -e "Logs will be gathered once all testers reports gathered sleep for $(expr ${ListentDurationInMinutes} \* 6 ) seconds  " >> ${LOCALSAVE}/${ConfFileName}.log
done
for host in ${ALLIPsUniq}
do
    scp -rP ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@\${host}:${REMOTESAVE}/${BlockName}-LocalLogs ${LOCALSAVE}/${BlockName}-Logs/\${host}
done
echo -e "all logs gathered saved to ${LOCALSAVE}/${BlockName}-Logs/" >>  ${LOCALSAVE}/${ConfFileName}.log
EOF
}
######################Start######################
#essential Validation 
#validate linux shell and conf file provided
mkdir -p ${LOCALSAVE}
echo -e "[*] - Start Basic Validation"|tee -a ${LOCALSAVE}/${ConfFileName}.log
if [ -z $1 ] 
then 
    Raise Error 1 |tee -a ${LOCALSAVE}/${ConfFileName}.log
else 
    echo -e "\tConfiguration File : ok"| tee -a ${LOCALSAVE}/${ConfFileName}.log
fi
if [ $(uname -s) != "Linux" ] 
then 
    Raise_Error 2 |tee -a ${LOCALSAVE}/${ConfFileName}.log
else
    echo -e "\tCurrent Shell : ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
fi
#validate no duplicate BlockNames/BlockAttributesNames
echo -e "\tChecking Duplicate Block Names:" |tee -a ${LOCALSAVE}/${ConfFileName}.log
for BlockName in ${BlocksNames}
do
    if [ $(echo "${BlocksNames}"|grep ${BlockName} | wc -l)  !=  1 ] 
    then
        Raise_Error 3 |tee -a ${LOCALSAVE}/${ConfFileName}.log
    else
        echo -e "\t\t${BlockName} : ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    fi
done
echo -e "\tChecking Duplicate Attributes Names:" |tee -a ${LOCALSAVE}/${ConfFileName}.log
for BlockName in ${BlocksNames}
do
    BlockContent=$(echo "${ConfFileContent}" | sed  -n  /${BlockName}/,/EOB/p | sed /EOB/d |sed /${BlockName}\/d)
    BlockAttributesNames=$(echo "${BlockContent}"| grep ':'|cut -d':' -f1)
    echo -e "\t\t${BlockName}:" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    for BlockAttributeName in ${BlockAttributesNames}
    do
        if [ $(echo "${BlockAttributesNames}"|grep ${BlockAttributeName} | wc -l)  !=  1 ]
        then
            Raise_Error 4 |tee -a ${LOCALSAVE}/${ConfFileName}.log
        else
            echo -e "\t\t\t${BlockAttributeName} : ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        fi
    done
done
#make sure the current host have nc/at
Validate_Install_Dependencies localhost
#write to $CONFPATH
echo -e "[*] - create a well formated configuration file at : \033[0;32m  ${CONFPATH} \033[0m " |tee -a ${LOCALSAVE}/${ConfFileName}.log
echo -n > ${CONFPATH}
for BlockName in ${BlocksNames}
do
    unset BlockContent BlockAttributesNames
	BlockContent=$(echo "${ConfFileContent}" | sed  -n  /${BlockName}/,/EOB/p | sed /EOB/d |sed /${BlockName}\/d)
	BlockAttributesNames=$(echo "${BlockContent}"| grep ':'|cut -d':' -f1)
	case ${BlockName} in 
		Default)
			for BlockAttributeName in ${BlockAttributesNames}
			do
				case ${BlockAttributeName} in
					User|Mode|ListentDurationInMinutes)
                        unset BlockAttributeContent
            	        BlockAttributeContent=$(echo "${BlockContent}"|grep -i ${BlockAttributeName}|cut -d':' -f2)
						case ${BlockAttributeName} in
							User)
								echo "Default_User:${BlockAttributeContent}" >> ${CONFPATH}
							;;
							Mode)
								echo "Default_Mode:${BlockAttributeContent}" >> ${CONFPATH}
							;;
							ListentDurationInMinutes)
								echo "Default_ListentDurationInMinutes:${BlockAttributeContent}" >> ${CONFPATH}
							;;
						esac
					    ;;
					*)
                        Raise_Error 5 ${BlockAttributeName} "can not be provided to the Default Block"
					;;
				esac
			done
		    ;;
		*)
			for BlockAttributeName in ${BlockAttributesNames}
			do
				case ${BlockAttributeName} in
					User|Mode|ListentDurationInMinutes|TCPPorts|UDPPorts|IPs|TestersIPs|ListenersIPs)
						case ${BlockAttributeName} in
							User|Mode|ListentDurationInMinutes|TCPPorts|UDPPorts)
                                unset BlockAttributeContent
    			                BlockAttributeContent=$(echo "${BlockContent}"|grep -i ${BlockAttributeName}|cut -d':' -f2)
                                case ${BlockAttributeName} in
                                    User)
                                        echo "${BlockName}_User:${BlockAttributeContent}" >> ${CONFPATH}
                                    ;;
                                    Mode)
                                        echo "${BlockName}_Mode:${BlockAttributeContent}" >> ${CONFPATH}
                                    ;;
                                    ListentDurationInMinutes)
                                        echo "${BlockName}_ListentDurationInMinutes:${BlockAttributeContent}" >> ${CONFPATH}
                                    ;;
                                    TCPPorts)
                                        echo "${BlockName}_TCPPorts:${BlockAttributeContent}" >> ${CONFPATH}
                                    ;;
                                    UDPPorts)
                                        echo "${BlockName}_UDPPorts:${BlockAttributeContent}" >> ${CONFPATH}
                                    ;;
                                esac
						        ;;
						    IPs|TestersIPs|ListenersIPs)
								unset BlockAttributeContent
                                BlockAttributeContent=$(echo "${BlockContent}"|sed -n "/${BlockAttributeName}/,/^[A-Za-z]/p"|grep -v ':'|tr '\n' ','|rev|cut -c2-|rev)
								case ${BlockAttributeName} in
									IPs)
										echo "${BlockName}_IPs:${BlockAttributeContent}" >> ${CONFPATH}
									;;
									TestersIPs)
										echo "${BlockName}_TestersIPs:${BlockAttributeContent}" >> ${CONFPATH}
									;;
									ListenersIPs)
										echo "${BlockName}_ListenersIPs:${BlockAttributeContent}" >> ${CONFPATH}
									;;
								esac
							    ;;
						esac
				        ;;
				    *)
                        Raise_Error 5 ${BlockAttributeName} "invalide attribute name"
					    ;;
				esac
			done
		    ;;
	esac
done
# Check If Blocks fulfilled with needed attributes
# default value can fill missing mode/user/listen duration attributes
echo -e "[*] - validate blocks attributes keys:"  |tee -a ${LOCALSAVE}/${ConfFileName}.log
for BlockName in ${BlocksNames}
do
	if [ ${BlockName} != "Default" ]
	then 
		for BlockAttributeName in User Mode ListentDurationInMinutes
		do
			grep -q ${BlockName}_${BlockAttributeName} ${CONFPATH}
            exit_status=$? 
			if [ ${exit_status} -ne 0 ]
			then 
				grep -q Default_${BlockAttributeName} ${CONFPATH}
                exit_status=$?
				if [ ${exit_status} -eq 0 ]
				then
					echo "${BlockName}_${BlockAttributeName}:$(grep Default_${BlockAttributeName} ${CONFPATH}| cut -d':' -f2)" >> ${CONFPATH}
                else
                    Raise_Error 6  ${BlockAttributeName} "Have to be specified, there is no default value"
				fi
			fi
		done
# {tcp/udp}ports one of them must existe
# uni mode requires listeners/testers ips and bi require ips
        unset Mode
		Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
		case ${Mode} in
			bi)
				egrep -q "${BlockName}_TestersIPs|${BlockName}_ListenersIPs" ${CONFPATH} &&	Raise_Error 6 "TestersIPs/ListenersIPs" "bi mode should not have TestersIPs/ListenersIPs"
				grep -q "${BlockName}_IPs" ${CONFPATH} || Raise_Error 5 "IPs" "bi mode should have IPs"
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" ${CONFPATH} || Raise_Error 5  "TCPPorts/UDPPorts" "at least one should be specified "
			    ;;
			uni)
				grep -q "${BlockName}_IPs" ${CONFPATH} &&	Raise_Error 6 "IPs" "uni mode should not have IPs"
				grep -q "${BlockName}_TestersIPs" ${CONFPATH}  || Raise_Error 5 "TestersIPs" "bi mode should have TestersIPs"
				grep -q "${BlockName}_ListenersIPs" ${CONFPATH} || Raise_Error 5 "ListenersIPs" "bi mode should have IPs ListenersIPs"
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" ${CONFPATH} || Raise_Error 5 "TCPPorts/UDPPorts" "at least one should be specified "
			    ;;
			*)
                Raise_Error 5 ${Mode} "mode should be uni/bi"
			    ;;
		esac
	fi
done
#validate the attributes values
#modes values  already validated in previous check
#ListentDurationInMinutes  value must be an integer
#ips match ips regex
#ports intger from 0 - 65536
#validate remote ips ssh access and sudo no passwd privilege

echo -e "[*] - validate blocks attributes values" |tee -a ${LOCALSAVE}/${ConfFileName}.log

for BlockName in ${BlocksNames}
do  
echo -e "\t${BlockName}:" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    grep -q ${BlockName}_ListentDurationInMinutes ${CONFPATH} 	&& 	ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d ':' -f2) && Validate_ListentDurationInMinutes ${ListentDurationInMinutes} ListentDurationInMinutes
    grep -q ${BlockName}_TCPPorts ${CONFPATH}	 	&&  TCPPorts=$( grep ${BlockName}_TCPPorts ${CONFPATH}|cut -d ':' -f2 ) 		&& Validate_Ports ${TCPPorts} TCPPorts
    grep -q ${BlockName}_UDPPorts ${CONFPATH} 		&&  UDPPorts=$( grep ${BlockName}_UDPPorts ${CONFPATH}|cut -d ':' -f2 ) 		&& Validate_Ports ${UDPPorts} UDPPorts
    grep -q ${BlockName}_IPs ${CONFPATH} 			&&  IPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d ':' -f2) 					&& Validate_IPS ${IPs}  IPs
    grep -q ${BlockName}_TestersIPs ${CONFPATH} 	&&  TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d ':' -f2)		&& Validate_IPS ${TestersIPs} TestersIPs
    grep -q ${BlockName}_ListenersIPs ${CONFPATH} 	&&  ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d ':' -f2)	&& Validate_IPS ${ListenersIPs} ListenersIPs
    if [ ${BlockName} != Default ]
    then 
        unset User  Mode IPs TestersIPs ListenersIPs Expanded_TestersIPs Expanded_ListenersIPs
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && ListenersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        case ${Mode} in
        uni)
            expand_ips "ListenersIPs:${ListenersIPs}"
            expand_ips "TestersIPs:${TestersIPs}"
            for ListenerIP in ${Expanded_ListenersIPs}
            do 
                Validate_Access ${ListenerIP} 
                 ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} "$(typeset -f Validate_Install_Dependencies);   Validate_Install_Dependencies ${ListenerIP}" 
            done
            for TesterIP in ${Expanded_TestersIPs}
            do 
                Validate_Access ${TesterIP}
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${TesterIP} "$(typeset -f Validate_Install_Dependencies);   Validate_Install_Dependencies ${ListenerIP} "

            done
            ;;
        bi)
            expand_ips "ListenersIPs:${ListenersIPs}"
            for ListenerIP in ${Expanded_ListenersIPs}
            do
                Validate_Access ${ListenerIP}
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} "$(typeset -f Validate_Install_Dependencies);   Validate_Install_Dependencies ww" &> /dev/null

            done
            ;;
        esac
    fi
done
echo -e "[*] - create/execute Listeners/Testers scripts:"  |tee -a ${LOCALSAVE}/${ConfFileName}.log
#create listeners/testers scripts and execute them remotly and create a local task to check if any report finished every 10 minutes and aggregate them
for BlockName in ${BlocksNames}
do
    if [ ${BlockName} != Default ]
    then 
        echo -e "\t\033[0;32m${BlockName}\033[0m:" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts Expanded_TestersIPs Expanded_ListenersIPs
        mkdir -p ${LOCALSAVE}/${BlockName}-Scripts/{Listeners,Testers,ReportsGathering}/
        mkdir -p ${LOCALSAVE}/${BlockName}-{Reports,Logs}
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d':' -f2)
        grep -q ${BlockName}_TCPPorts ${CONFPATH} &&  TCPPorts=$( grep ${BlockName}_TCPPorts ${CONFPATH}|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts ${CONFPATH} &&  UDPPorts=$( grep ${BlockName}_UDPPorts ${CONFPATH}|cut -d ':' -f2 )
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && ListenersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        if [ ${User} = root ] 
        then
            ATCMD="at now"
            REMOTEHOME=/root
        else
            ATCMD="sudo -E --preserve-env=HOME at now"
            REMOTEHOME=/home/${User}
        fi
        REMOTESAVE="${REMOTEHOME}/CommsMatrix/${ConfFileName}-${ExecutionDate}"
        #convert the input to spaced individual ips 
        expand_ips "ListenersIPs:${ListenersIPs}"
        expand_ips "TestersIPs:${TestersIPs}"
        # take the listener spaced ips and generate the scripts
        for ListenerIP in ${Expanded_ListenersIPs}
        do 
            echo -e "\t\tListener:\033[0;32m ${ListenerIP}  ok \033[0m " |tee -a ${LOCALSAVE}/${ConfFileName}.log
            generate_listeners
            grep -q ${BlockName}_TCPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-tcp.sh &> /dev/null
            grep -q ${BlockName}_UDPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-udp.sh &> /dev/null
            for TesterIP  in ${Expanded_TestersIPs}
            do
                [ ${TesterIP} = ${ListenerIP} ] && continue 
                echo -e "\t\t\tTester:\033[0;32m${TesterIP}=>${ListenerIP} ok \033[0m" |tee -a ${LOCALSAVE}/${ConfFileName}.log
                generate_testers
                grep -q ${BlockName}_TCPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-tcp.sh &> /dev/null
                grep -q ${BlockName}_UDPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-udp.sh &> /dev/null
                [ -z ${TCPPorts} ] ||  echo  "${TesterIP}-${ListenerIP}-tcp" >> ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ExpectedDoneList
                [ -z ${UDPPorts} ] ||  echo  "${TesterIP}-${ListenerIP}-udp" >> ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ExpectedDoneList
            done
        done
    fi
done  
echo -e "[*] - Create LocalTasks for Reports Gathering" |tee -a ${LOCALSAVE}/${ConfFileName}.log
for BlockName in ${BlocksNames}
do
    if [ ${BlockName} != Default ]
    then             
        echo -e "\t\033[0;32m${BlockName}\033[0m:interval=$(expr ${ListentDurationInMinutes} \* 6) seconds" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d':' -f2)
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && ListenersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${User} = root ] &&  REMOTEHOME="/root" ||   REMOTEHOME="/home/${User}"
        REMOTESAVE="${REMOTEHOME}/CommsMatrix/${ConfFileName}-${ExecutionDate}"
        expand_ips "TestersIPs:${TestersIPs}"
        expand_ips "ListenersIPs:${ListenersIPs}"
        ALLIPsUniq=$(echo "${Expanded_TestersIPs} ${Expanded_ListenersIPs}"|tr ' ' '\n'|sort|uniq|tr '\n' ' ')
        for TesterIP  in ${Expanded_TestersIPs}
        do
            touch ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-{ExpectedDoneList,ActualDoneList}
            echo -e "\t\t${TesterIP}:path=\033[0;32m ${LOCALSAVE}/${BlockName}-Reports/${TesterIP} \033[0m"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalLogs/ActualDoneList ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ActualDoneList/ &> /dev/null
            Generate_Collect_Reports &> /dev/null
            at now  -f ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}.sh &> /dev/null
            echo -e "${BlockName}-${TesterIP}" >> ${LOCALSAVE}/${BlockName}-Reports/ExpectedCollectedReports
        done
        echo -e "[*] - Create LocalTask for Logs Gathering" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        touch ${LOCALSAVE}/${BlockName}-Reports/{ExpectedCollectedReports,ActualCollectedReports}
        Generate_Collect_Logs
        at now -f ${LOCALSAVE}/${BlockName}-Scripts/logs_gathering.sh 
    fi
done
echo -e "[*] - check configuration file: ${LOCALSAVE}/${ConfFileName}.conf "
echo -e "[*] - check ${0} logs:  ${LOCALSAVE}/${ConfFileName}.log"
echo -e "[*] - check Generated Scripts:${LOCALSAVE}/<BlockName>-Scripts"
echo -e "[*] - check Gathered Reports:${LOCALSAVE}/<BlockName>-Reports"
echo -e "[*] - check Gathered Logs:${LOCALSAVE}/<BlockName>-Logs"
echo -e "####################Start Report Gathering #######################" >> ${LOCALSAVE}/${ConfFileName}.log