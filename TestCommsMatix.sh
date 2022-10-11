#!/bin/bash
export TOP_PID=$$
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
    echo -en "\t\033[0;31mError\033[0m:\t"
    case $1 in
        1)
            echo -e "configuration file not specified .. file format as following\n#####${CONF_EXAMPLE}\n#####"
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
    sudo kill -9 ${TOP_PID}
}
if [ -z $1 ] 
then 
    Raise_Error 1 |tee -a ${LOCALSAVE}/${ConfFileName}.log
else 
    echo -e "\tConfiguration File : ok"| tee -a ${LOCALSAVE}/${ConfFileName}.log
fi
####
unset ConfFileName ConfFileContent BlocksNames ExecutionDate LOCALSAVE CONFPATH
ConfFileContent=$(egrep -v '^$|^#' $1|tr -d ' '|sed 's/\[/EOB\n\[/g'|sed '1d'|sed -e '$a\EOB')
ConfFileName=$(echo ${1##*/}|tr -d ' '|sed 's/.conf//')
BlocksNames=$(echo "${ConfFileContent}" |grep '\['|tr -d '['|tr -d ']') 
ExecutionDate=$(date  +"%Y_%m_%d_%H_%M_%S")
LOCALSAVE="${HOME}/CommsMatrix/${ConfFileName}-${ExecutionDate}"
CONFPATH="${LOCALSAVE}/${ConfFileName}.conf"
SSH_PORT=22
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
                Raise_Error 7 $2 "port ${Ports} is not integer"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            elif [ ${Ports} -lt 0 -o ${Ports} -gt 65536 ]
            then 
                Raise_Error 7 $2 "Port Range is 0=>65536"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            fi
        fi
    done
    echo -e "\t\tPort Range  ${1} : ok"|tee -a ${LOCALSAVE}/${ConfFileName}.log
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
                    Raise_Error 7 $2 "can not be zero or negative"|tee -a ${LOCALSAVE}/${ConfFileName}.log
                else
                    echo -e "\t\tListenDuration $1 : ok "
				fi
			else 
                    Raise_Error 7 $2 "is not an integer"|tee -a ${LOCALSAVE}/${ConfFileName}.log
			fi
}
Validate_Access(){
    echo -e "\t\t${1} Access/Authorization:" | tee -a ${LOCALSAVE}/${ConfFileName}.log
    socat  /dev/null  tcp4:${1}:${SSH_PORT}  &> /dev/null
    exit_status=$?
    if [ ${exit_status} -ne 0 ]  
    then
        Raise_Error 8 ${1} "\tssh@${1} : down" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    else
        echo -e -e "\t\t\tssh port : ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
    fi
    ssh -q -p ${SSH_PORT}  -o PasswordAuthentication=no -o StrictHostKeyChecking=no ${User}@${1} sudo -vn &> /dev/null
    exit_status=$?
    if [ ${exit_status} -eq 0 ]
    then
        echo -e "\t\t\tpubkey/sudo no passwd : ok "|tee -a ${LOCALSAVE}/${ConfFileName}.log 
    elif [ ${exit_status} -eq 1 ]
    then
        Raise_Error 10 ${1} "\t\t:${User} is not sudoer nopasswd on remote server"|tee -a ${LOCALSAVE}/${ConfFileName}.log
    elif [ ${exit_status} -eq 255 ]
    then
        Raise_Error 9 ${1} "\t\t${1}:${USER} publickey is not authorized on ${User}@${1}"|tee -a ${LOCALSAVE}/${ConfFileName}.log
    elif [ ${exit_status} -ne 0 ]
    then
        Raise_Error 10 ${1} "\t\t${1}:ssh generic  Error"|tee -a ${LOCALSAVE}/${ConfFileName}.log
    fi
}
Validate_Install_Dependencies () {
    [ $1 = localhost ] &&    echo -e "\t${1} Dependencies: "  ||     echo -e "\t\t${1} Dependencies:"
    if  [ -e /bin/dash ] 
    then
        diff /bin/sh /bin/dash &> /dev/null
        exit_status=$?
        if [ ${exit_status} -eq 0 ]
        then
            sudo ln -sf /bin/bash /bin/sh && echo -e "\t\t\tatd service default shell changed from sh to bash on " 
        else
            echo -e "\t\t\tatd service default shell is bash no change needed" 
        fi
    else
            echo -e "\t\t\tatd service default shell is bash no change needed" 
    fi
    echo -e "\t\t\tchecking for netcat/atd packages" 
    for PackageManager in "yum" "apt-get" 
    do
        for Package in "at" "socat"
        do
            which ${PackageManager} &> /dev/null
            exit_status=$?
            if [ $exit_status -eq 0 ]
            then
                which ${Package} &> /dev/null 
                exit_status=$?
                if [ ${exit_status} -eq 0 ]
                then
                    echo -e "\t\t\t\tpackage ${Package} is already installed" 
                else 
                    sudo ${PackageManager} install -y -q  ${Package}  && echo -e "\t\t\t\t${Package} is not installed ,installing .."
                fi
                [ ${Package} = "at" ] &&  sudo  systemctl stop atd  ; sudo nohup atd -b 1 -l $(cat /proc/cpuinfo|grep processor|wc -l)  & &> /dev/null
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
expand_ports () {
    unset Expanded_Ports count
    Total=0
    for PortRange in $(echo $1|cut -d ':' -f2 |tr ',' ' ')
    do
        echo ${PortRange}|grep -q '-'
        exit_status=$?
        if [ ${exit_status} -eq 0 ]
        then
                Start_Port=$(echo ${PortRange}|cut -d '-' -f1 )
                End_Port=$(echo ${PortRange}|cut -d '-' -f2 )
                
                for Port in $(seq ${Start_Port} ${End_Port})
                do
                    Expanded_Ports="${Expanded_Ports} ${Port}"
                    (( Total++ ))
                done
        else
                    Expanded_Ports="${Expanded_Ports} ${PortRange}"
                    (( Total++ ))
        fi     
    done
    Protocol=$(echo $1|cut -d ':' -f1)
    if [ ${Protocol} = TCPPorts ]
    then
        Expanded_TCPPorts=${Expanded_Ports}
        Total_TCP=${Total}
    elif [ ${Protocol} = UDPPorts ]
    then
        Expanded_UDPPorts=${Expanded_Ports} 
        Total_UDP=${Total}
    fi
}
#4-Generate script for listeners/testers/report gathering
generate_listeners () {
            [ -z ${TCPPorts} ] || cat <<TCPLSNR > ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-tcp.sh
            #!/bin/bash
            mkdir -p ${REMOTESAVE}/Flags
            mkdir -p ${REMOTESAVE}/${BlockName}-LocalLogs
            touch ${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-TCP-ListenPorts.txt
            FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            if [ \${FWStatus} = active ] 
            then
                echo -e "Firewall on ${ListenerIP} was up: stop for ${ListentDurationInMinutes} Minutes"  &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            else
                echo -e "Firewall on ${ListenerIP} was down: no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
            fi
            echo -e "Start Listening on tcp Ports ${ListenerIP}:${TCPPorts} " &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
            for Port in ${Expanded_TCPPorts}
            do
                socat  tcp4:${ListenerIP}:\${Port},connect-timeout=0.1 /dev/null
                exit_status=\$?
                if [ \${exit_status} -ne 0 ]
                then
                    echo -e tcp ${ListenerIP}:\${Port} was down , bringing it up for ${ListentDurationInMinutes} Minutes &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                    echo "socat TCP-L:\${Port},reuseaddr,fork,bind=${ListenerIP} SYSTEM:'echo tcp:${BlockName}'"|at now
                    echo port ${ListenerIP}:\${Port} tcp is running will be killed after ${ListentDurationInMinutes} Minutes &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                else
                    echo Port \${Port} on ${ListenerIP} was up , no change needed &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-tcp.log
                fi
            done
            echo up >> ${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-TCP-ListenPorts.txt
            echo pkill -9 -f \"SYSTEM:echo tcp:${BlockName}\"|at now +${ListentDurationInMinutes} minutes

TCPLSNR
            [ -z ${UDPPorts} ] || cat <<UDPLSNR > ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-udp.sh
            #!/bin/bash
            mkdir -p ${REMOTESAVE}/Flags
            mkdir -p ${REMOTESAVE}/${BlockName}-LocalLogs
            touch ${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-UDP-ListenPorts.txt
            FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            if [ \${FWStatus} = active ]
            then
                echo -e "Firewall on ${ListenerIP} was up: stop for ${ListentDurationInMinutes} Minutes"  &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            else
                echo -e "Firewall on ${ListenerIP} was down: no change needed" &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
            fi
            echo -e "Start Listening on udp Ports ${ListenerIP}:${UDPPorts} " &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
            for Port in ${Expanded_UDPPorts}
            do
                echo udp ${ListenerIP}:\${Port} was down , bringing it up for ${ListentDurationInMinutes} Minutes &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
                echo "socat UDP4-RECVFROM:\${Port},fork,bind=${ListenerIP} SYSTEM:'echo udp:${BlockName}'"|at now
                echo port ${ListenerIP}:\${Port} udp is running will be killed after ${ListentDurationInMinutes} Minutes &>>  ${REMOTESAVE}/${BlockName}-LocalLogs/${ListenerIP}-udp.log
            done
            echo up >> ${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-UDP-ListenPorts.txt
            echo pkill -9 -f \"SYSTEM:echo udp:${BlockName}\"|at now +${ListentDurationInMinutes} minutes
UDPLSNR
}
generate_testers () {
                [ -z ${TCPPorts} ] || cat <<TCPTSTR > ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-tcp.sh
                #!/bin/bash
                mkdir -p ${REMOTESAVE}/${BlockName}-{LocalReports,LocalLogs}
                mkdir -p ${REMOTESAVE}/Flags
                touch ${REMOTESAVE}/Flags/${BlockName}-${TesterIP}-AllTested
                for Port in ${Expanded_TCPPorts}
                do
                    socat  /dev/null  tcp4:${ListenerIP}:\${Port},connect-timeout=2
                    exit_status=\$?
                    if [ \${exit_status} -eq 0 ]
                    then
                        echo "tcp:${ListenerIP}:\${Port} is up" &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt
                    else
                        echo "tcp:${ListenerIP}:\${Port} is down" &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt
                    fi
                done
                echo -e "BlockName,TesterIP,ListenerIP,Protocol,Total,Success,Failure\n${BlockName},${TesterIP},${ListenerIP},tcp,${Total_TCP},\$(grep -c  "is up" ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt),\$(grep -c  "is down" ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt)" >> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-tcp.log
                echo  "${TesterIP}-${ListenerIP}-tcp" >> ${REMOTESAVE}/Flags/${BlockName}-${TesterIP}-AllTested
TCPTSTR
            [ -z ${UDPPorts} ] || cat <<UDPTSTR > ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-udp.sh
            #!/bin/bash
            mkdir -p ${REMOTESAVE}/${BlockName}-{LocalReports,LocalLogs}
            mkdir -p  ${REMOTESAVE}/Flags
            touch ${REMOTESAVE}/Flags/${BlockName}-${TesterIP}-AllTested
            for Port in ${Expanded_UDPPorts}
            do                
                echo "Test udp ${TesterIP}=>${ListenerIP}:\${Port}" &>> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
                unset result
                result=\$( echo '' | socat -t 2 udp:${ListenerIP}:\${Port} STDIO) 
                exit_status=\$?
                if [ \${exit_status} -eq 0 ]
                then
                    if [ \${result} = "udp" ]
                    then
                        echo "udp:${ListenerIP}:\${Port} is up" &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt
                    else
                        echo "udp:${ListenerIP}:\${Port} is down" &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt
                    fi
                else
                        echo "udp:${ListenerIP}:\${Port} is down" &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt
                fi
            done
            echo  "${TesterIP}-${ListenerIP}-udp" >> ${REMOTESAVE}/Flags/${BlockName}-${TesterIP}-AllTested
            echo -e "BlockName,TesterIP,ListenerIP,Protocol,Total,Success,Failure\n${BlockName},${TesterIP},${ListenerIP},udp,${Total_UDP},\$(grep -c  "is up" ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt),\$(grep -c  "is down" ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt)" >> ${REMOTESAVE}/${BlockName}-LocalLogs/${TesterIP}-${ListenerIP}-udp.log
UDPTSTR
}
Generate_Collect_Reports () {
cat <<REPORTCOLLECTOR > ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}.sh
scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/Flags/${BlockName}-${TesterIP}-AllTested ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ActualDoneList
until [ "\$(sort -n ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ExpectedDoneList)" = "\$(sort -n ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ActualDoneList)" ]
do
    echo -e "Waiting for ${BlockName} => ${TesterIP} to finish testing sleep for 60 seconds " >> ${LOCALSAVE}/${ConfFileName}.log
    sleep 70
    scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/Flags/${BlockName}-${TesterIP}-AllTested ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ActualDoneList 
done
scp -rP ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalReports ${LOCALSAVE}/${BlockName}-Reports/${TesterIP}
echo -e "${BlockName}=>${TesterIP} finished testing reports saved to ${LOCALSAVE}/${BlockName}-Reports/${TesterIP}" >>  ${LOCALSAVE}/${ConfFileName}.log
echo -e "${BlockName}-${TesterIP}" >> ${LOCALSAVE}/${BlockName}-Reports/ActualCollectedReports
REPORTCOLLECTOR
}
Generate_Collect_Logs () {
cat <<LOGCOLLECTOR > ${LOCALSAVE}/${BlockName}-Scripts/logs_gathering.sh
until [ "\$(sort -n ${LOCALSAVE}/${BlockName}-Reports/ActualCollectedReports)" = "\$(sort -n ${LOCALSAVE}/${BlockName}-Reports/ExpectedCollectedReports )" ]
do
    echo -e "\$(date):Logs will be gathered once all testers reports gathered sleep for 120 seconds  " >> ${LOCALSAVE}/${ConfFileName}.log
    sleep 80 
done
for IP in ${ALLIPsUniq}
do
    scp -rP ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@\${IP}:${REMOTESAVE}/${BlockName}-LocalLogs ${LOCALSAVE}/${BlockName}-Logs/\${IP}
    echo -e "${BlockName}:\${IP} logs gathered saved to ${LOCALSAVE}/${BlockName}-Logs/" >>  ${LOCALSAVE}/${ConfFileName}.log
done
echo -e "\$(date):all ${BlockName} logs gathered saved to ${LOCALSAVE}/${BlockName}-Logs/" >>  ${LOCALSAVE}/${ConfFileName}.log
###generate stats
echo -e "\$(date):${BlockName} testing stats saved to ${LOCALSAVE}/${ConfFileName}.csv " >>  ${LOCALSAVE}/${ConfFileName}.log
tail -n 1  ${LOCALSAVE}/${BlockName}-Logs/*/*-*-*.log|egrep -v '=|^$' >> ${LOCALSAVE}/${ConfFileName}.csv
LOGCOLLECTOR
}
######################Start######################
#essential Validation 
#validate Linux shell and configuration file provided
mkdir -p ${LOCALSAVE}
echo -e "[*] - Start Basic Validation"|tee -a ${LOCALSAVE}/${ConfFileName}.log

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
    for BlockAttributeName in ${BlockAttributesNames}
    do
        if [ $(echo "${BlockAttributesNames}"|grep ${BlockAttributeName} | wc -l)  !=  1 ]
        then
            Raise_Error 4 |tee -a ${LOCALSAVE}/${ConfFileName}.log
        fi
    done
    echo -e "\t\t${BlockName} Attributes : ok" |tee -a ${LOCALSAVE}/${ConfFileName}.log
done
#make sure the current host have socat/at
Validate_Install_Dependencies localhost |tee -a ${LOCALSAVE}/${ConfFileName}.log
#write to $CONFPATH
echo -e "[*] - create a well formatted configuration file at : \033[0;32m  ${CONFPATH} \033[0m " |tee -a ${LOCALSAVE}/${ConfFileName}.log
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
                        Raise_Error 5 ${BlockAttributeName} "invalid attribute name"
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
# {tcp/udp}ports one of them must exist
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
#ports integer from 0 - 65536
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
        unset User  Mode IPs TestersIPs ListenersIPs Expanded_TestersIPs Expanded_ListenersIPs ALLIPsUniq
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && ListenersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        expand_ips "TestersIPs:${TestersIPs}"
        expand_ips "ListenersIPs:${ListenersIPs}"
        ALLIPsUniq=$(echo "${Expanded_TestersIPs} ${Expanded_ListenersIPs}"|tr ' ' '\n'|sort|uniq|tr '\n' ' ')
        for IP in ${ALLIPsUniq}
        do
                Validate_Access ${IP} 
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${IP} "$(typeset -f Validate_Install_Dependencies);  Validate_Install_Dependencies ${IP}" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        done
    fi
done
echo -e "[*] - create/execute Listeners/Testers scripts:"  |tee -a ${LOCALSAVE}/${ConfFileName}.log
#create listeners/testers scripts and execute them remotely and create a local task to check if any report finished every 10 minutes and aggregate them
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
        [ -z ${TCPPorts} ] || expand_ports "TCPPorts:${TCPPorts}"
        [ -z ${UDPPorts} ] || expand_ports "UDPPorts:${UDPPorts}"
        export -f generate_testers
        # take the listener spaced ips and generate the scripts
        grep -q ${BlockName}_TCPPorts ${CONFPATH} &> /dev/null
        exit_status=$?
        if [ ${exit_status} -eq 0 ]
        then
            for ListenerIP in ${Expanded_ListenersIPs}
            do 
                echo -e "\t\tListener:\033[0;32m ${ListenerIP}  ok \033[0m " |tee -a ${LOCALSAVE}/${ConfFileName}.log
                generate_listeners
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-tcp.sh &> /dev/null
                for TesterIP  in ${Expanded_TestersIPs}
                do
                    [ ${TesterIP} = ${ListenerIP} ] && continue
                    echo -e "\t\t\tTester:${TesterIP}-TCP Will be executed once all listener ports ready" |tee -a ${LOCALSAVE}/${ConfFileName}.log
                    generate_testers
                    echo  "${TesterIP}-${ListenerIP}-tcp" >> ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ExpectedDoneList
                    cat <<TCPTASK | at now  &> /dev/null
                    scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP}:${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-TCP-ListenPorts.txt ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${ListenerIP}-ALL-TCP-Listen.txt &> /dev/null
                    until [ "\$(grep up ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${ListenerIP}-ALL-TCP-Listen.txt )" = "up" ]
                    do
                        sleep 60
                        scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP}:${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-TCP-ListenPorts.txt ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${ListenerIP}-ALL-TCP-Listen.txt &> /dev/null
                    done
                    echo -e "Tester:tcp:${TesterIP}=>${ListenerIP} ok" >> ${LOCALSAVE}/${ConfFileName}.log
                    ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD}  < ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-tcp.sh &> /dev/null
TCPTASK
                done
            done
        fi
        grep -q ${BlockName}_UDPPorts ${CONFPATH}  &> /dev/null
        exit_status=$?
        if [ ${exit_status} -eq 0 ]
        then
            for ListenerIP in ${Expanded_ListenersIPs}
            do 
                echo -e "\t\tListener:\033[0;32m ${ListenerIP}  ok \033[0m " |tee -a ${LOCALSAVE}/${ConfFileName}.log
                generate_listeners
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-udp.sh &> /dev/null
                for TesterIP  in ${Expanded_TestersIPs}
                do
                    [ ${TesterIP} = ${ListenerIP} ] && continue 
                    echo -e "\t\t\tTester:${TesterIP}-UDP Will be executed once all listener ports ready" |tee -a ${LOCALSAVE}/${ConfFileName}.log
                    generate_testers
                    echo  "${TesterIP}-${ListenerIP}-udp" >> ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-ExpectedDoneList
                    cat <<UDPTASK | at now &> /dev/null
                    scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP}:${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-UDP-ListenPorts.txt ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${ListenerIP}-ALL-UDP-Listen.txt &> /dev/null
                    until [ "\$(grep up ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${ListenerIP}-ALL-UDP-Listen.txt )" = "up" ]
                    do
                        sleep 60
                        scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP}:${REMOTESAVE}/Flags/${BlockName}-${ListenerIP}-ALL-UDP-ListenPorts.txt ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${ListenerIP}-ALL-UDP-Listen.txt &> /dev/null
                    done
                    echo -e "Tester:udp:${TesterIP}=>${ListenerIP} ok" >> ${LOCALSAVE}/${ConfFileName}.log
                    ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-udp.sh &> /dev/null
UDPTASK
                done
            done
        fi
    fi
done  
echo -e "[*] - Create LocalTasks for Reports Gathering" |tee -a ${LOCALSAVE}/${ConfFileName}.log
echo 'BlockName,TesterIP,ListenerIP,Protocol,Total,Success,Failure' > ${LOCALSAVE}/${ConfFileName}.csv
for BlockName in ${BlocksNames}
do
    if [ ${BlockName} != Default ]
    then             
        echo -e "\t\033[0;32m${BlockName}\033[0m:interval=$(expr ${ListentDurationInMinutes} \* 6) seconds" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts Expanded_TestersIPs Expanded_ListenersIPs
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
        touch ${LOCALSAVE}/${BlockName}-Reports/{ExpectedCollectedReports,ActualCollectedReports}
        for TesterIP  in ${Expanded_TestersIPs}
        do
            touch ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}-{ExpectedDoneList,ActualDoneList}
            echo -e "\t\t${TesterIP}:path=\033[0;32m ${LOCALSAVE}/${BlockName}-Reports/${TesterIP} \033[0m"|tee -a ${LOCALSAVE}/${ConfFileName}.log
            Generate_Collect_Reports &> /dev/null
            at now  -f ${LOCALSAVE}/${BlockName}-Scripts/ReportsGathering/${TesterIP}.sh &> /dev/null
            echo -e "${BlockName}-${TesterIP}" >> ${LOCALSAVE}/${BlockName}-Reports/ExpectedCollectedReports
        done
        echo -e "[*] - Create LocalTask for Logs Gathering" |tee -a ${LOCALSAVE}/${ConfFileName}.log
        Generate_Collect_Logs &> /dev/null
        at now -f ${LOCALSAVE}/${BlockName}-Scripts/logs_gathering.sh  &> /dev/null
    fi
done
echo -e "[*] - check configuration file: ${LOCALSAVE}/${ConfFileName}.conf "
echo -e "[*] - check ${0} logs:  ${LOCALSAVE}/${ConfFileName}.log"
echo -e "[*] - check stats:  ${LOCALSAVE}/${ConfFileName}.csv"
echo -e "[*] - check Generated Scripts:${LOCALSAVE}/<BlockName>-Scripts"
echo -e "[*] - check Gathered Reports:${LOCALSAVE}/<BlockName>-Reports"
echo -e "[*] - check Gathered Logs:${LOCALSAVE}/<BlockName>-Logs"
echo -e "[*] - check Local Logs:${LOCALSAVE}/<BlockName>-LocalLogs"
echo -e "[*] - check Local Reports:${LOCALSAVE}/<BlockName>-LocalReports"
echo -e "####################Start Report Gathering #######################" >> ${LOCALSAVE}/${ConfFileName}.log