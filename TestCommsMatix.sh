#!/bin/bash
unset ConfFileName ConfFileContent BlocksNames ExecutionDate LOCALSAVE CONFPATH
ConfFileContent=$(egrep -v '^$|^#' $1|tr -d ' '|sed 's/\[/EOB\n\[/g'|sed '1d'|sed -e '$a\EOB')
ConfFileName=$(echo ${1##*/}|tr -d ' '|sed 's/.conf//')
BlocksNames=$(echo "${ConfFileContent}" |grep '\['|tr -d '['|tr -d ']') 
ExecutionDate=$(date  +"%Y_%m_%d_%H_%M_%S")
LOCALSAVE="${HOME}/CommsMatrix/${ConfFileName}-${ExecutionDate}"
CONFPATH="${LOCALSAVE}/${ConfFileName}"
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
                    Raise_Error 6 $2 "Start port ${Start_Port} is not integer "
				elif ! [[ ${End_Port} == ?(-)+([0-9]) ]] 
                then
                    Raise_Error 6 $2 "End port ${End_Port} is not integer "
				elif [ ${Start_Port} -lt 0 -o ${Start_Port} -gt 65536 -o ${End_Port} -lt 0 -o ${End_Port} -gt 65536 ]
				then
					Raise_Error 6 $2 "Port Range is 0=>65536"
				elif [ ${Start_Port} -gt ${End_Port} ]
				then
					Raise_Error 6 $2 "Start port ${Start_Port} is greater than End port ${End_Port}"
				fi
			else
				if ! [[ ${Ports} == ?(-)+([0-9]) ]] 
				then
					Raise_Error 6 $2 "port ${Ports} is not intger"
				elif [ ${Ports} -lt 0 -o ${Ports} -gt 65536 ]
				then 
					Raise_Error 6 $2 "Port Range is 0=>65536"
				fi
			fi
		done
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
                    Raise_Error 6 $2 "Ip ${IP} bad format"
                fi
            done
            if [ ${Start_IP_OCT1} -ne ${End_IP_OCT1} -o ${Start_IP_OCT2} -ne ${End_IP_OCT2} -o ${Start_IP_OCT3} -ne ${End_IP_OCT3} ]
            then
                Raise_Error 6 $2 "Script support /24 range only,specified value ${Start_IP}=>${End_IP}"
            elif [ ${Start_IP_OCT4} -gt ${End_IP_OCT4} ]
            then 
                Raise_Error 6 $2 "Range ${Start_IP}=>${End_IP} Invalid"
            fi
		else 
			if ! [[ ${IPs} =~  ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
			then
				Raise_Error 6 $2 "Ip ${IPs} bad format"
			fi
		fi
	done
}
Validate_ListentDurationInMinutes () {
			if [[ $1 == ?(-)+([0-9]) ]] 
			then
				if [ $1 -le 0 ]
				then
                    Raise_Error 6 $2 "can not be zero or netgative"
				fi
			else 
                    Raise_Error 6 $2 "is not an integer"
			fi
}
Validate_Access(){
    nc -w 2 -z ${1} ${SSH_PORT} 
    exit_status=$?
    [ ${exit_status} -ne 0 ]  &&  Raise_Error 7
    ssh -q -p ${SSH_PORT}  -o PasswordAuthentication=no -o StrictHostKeyChecking=no ${User}@${1} sudo -vn &> /dev/null
    exit_status=$?
    if [ ${exit_status} -eq 1 ]
    then
        Raise_Error 9
    elif [ ${exit_status} -eq 255 ]
    then
        Raise_Error 8
    elif [ ${exit_status} -ne 0 ]
    then
        Raise_Error 9
    fi
}
Validate_Install_Dependencies () {
    which yum &> /dev/null
    exit_status=$?
    if [ $exit_status -eq 0 ]
    then
        which nc || sudo  yum install -y -q  nc
        which at || sudo  yum install -y -q at && sudo  systemctl start atd 
    fi
    which apt-get &> /dev/null
    exit_status=$?
    if [ $exit_status -eq 0 ]
    then
        which nc || sudo  apt-get install -y -q nc
        which at || sudo  apt-get install -y -q at && sudo  systemctl start atd
    fi
}
#2- show and log error function
Raise_Error () {
    echo -en "\t\033[0;31mError\033[0m:\n\t"
    case $1 in
        1)
            echo -e "\tsystem shell is not supported"
            ;;
        2)
            echo -e "\tDuplicate Block Name in ${BlockName}" 
            ;;
        3)
            echo -e "\tDuplicate Attribute Key in ${BlockName}=>${BlockAttributeName}" 
            ;;
        4)
            echo -e "\tInvalid Attribute $2 Key in ${BlockName}=>${Mode} \n\t\t\t$3" 
            ;;
        5)
            echo -e "\tAttribute $2 is Missing  in ${BlockName}\n\t\t\t$3"
            ;;
        6)
            echo -e "\tinvalide Attribute $2 Value in ${BlockName}\n\t\t\t$3"
            ;;
        7)
            echo -e "\thost unreachable via ssh ${BlockName}" 
            ;;
        8)
            echo -e "\t${USER} Publick key is not authorized on  ${BlockName} " 
            ;;
        9)
            echo -e  "\t${USER} is not sudoer nopasswd on  ${BlockName} " 
            ;;
    esac
    exit $1
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
    [ ${IPName} = ListenersIPs ] && Expanded_ListenersIPs=${Expanded_IPs} || Expanded_TestersIPs=${Expanded_IPs}
}
#4-Generate script for listeners/testers/report gathering
generate_listeners () {
        [ -z ${TCPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-tcp.sh
        #!/bin/bash
        FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
        [ \${FWStatus} = active ] && sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
        [ -e /tmp/TCP-Listener.py ] || echo "${Listener_TCPScript}" >> /tmp/TCP-Listener.py
        for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
        do
            echo "\${Ports}"|grep -q '-'
            exit_status=\$?
            if [ \${exit_status} -eq 0 ] 
            then
                Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                for Port in \$(seq \${Start_Port} \${End_Port})
                do
                    nc -w 2 -z ${ListenerIP} \${Port}
                    exit_status=\$?
                    if [ \${exit_status} -ne 0 ]
                    then
                        #echo "nc -4kl ${ListenerIP} \${Port}"|at now
                        #PID=\$( pgrep -la nc|grep "${ListenerIP} \${Port}"|cut -d' ' -f1)
                        #while [ -z \${PID} ] ; do   PID=\$( pgrep -la nc|grep "${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                        #echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                        echo "python /tmp/TCP-Listener.py ${ListenerIP} \${Port}"|at now
                        unset PID
                        PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1)
                        while [ -z \${PID} ] ; do PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                        echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    fi
                done
            else
                nc -w 2 -z ${ListenerIP} \${Ports}
                exit_status=\$?
                if [ \${exit_status} -ne 0 ]
                then
                    #echo "nc -4kl ${ListenerIP} \${Ports}"|at now
                    #PID=\$( pgrep -la nc|grep "${ListenerIP} \${Ports}"|cut -d' ' -f1)
                    #while [ -z \${PID} ] ; do   PID=\$( pgrep -la nc|grep "${ListenerIP} \${Ports}"|cut -d' ' -f1) ; done
                    #echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    echo "python /tmp/TCP-Listener.py ${ListenerIP} \${Ports}"|at now
                    unset PID
                    PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1)
                    while [ -z \${PID} ] ; do PID=\$(pgrep -la python|grep "/tmp/TCP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1) ; done
                    echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                fi
            fi
        done
EOF
            [ -z ${UDPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-udp.sh
            #!/bin/bash
            FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            [ \${FWStatus} = active ] && sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            [ -e /tmp/UDP-Listener.py ] || echo "${Listener_UDPScript}" >> /tmp/UDP-Listener.py
            for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
            do
                echo "\${Ports}"|grep -q '-'
                exit_status=\$?
                if [ \${exit_status} -eq 0 ] 
                then
                    Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                    End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                    for Port in \$(seq \${Start_Port} \${End_Port})
                    do
                        nc -uz -w 2 ${ListenerIP} \${Port}
                        exit_status=\$?
                        if [ \${exit_status} -ne 0 ]
                        then
                                echo "python /tmp/UDP-Listener.py ${ListenerIP} \${Port}"|at now
                                unset PID
                                PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1)
                                while [ -z \${PID} ] ; do PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                                echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                        fi
                    done
                else
                    nc -uz -w 2 ${ListenerIP} \${Ports}
                    exit_status=\$?
                    if [ \${exit_status} -ne 0 ]
                    then
                        echo "python /tmp/UDP-Listener.py ${ListenerIP} \${Ports}"|at now
                        unset PID
                        PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1)
                        while [ -z \${PID} ] ; do PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${ListenerIP} \${Ports}"|cut -d' ' -f1) ; done
                        echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    fi
                fi
            done
EOF
}
generate_testers () {
                [ -z ${TCPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-tcp.sh
                #!/bin/bash
                FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
                [ \${FWStatus} = active ] && sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
                mkdir -p ${REMOTESAVE}/${BlockName}-LocalReports
                touch ${REMOTESAVE}/${BlockName}-LocalReports/ActualDoneList
                for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
                do
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
                                for Port in \$(seq \${Start_Port} \${End_Port}) ; do nc -vz -w 2 ${ListenerIP} \${Port}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt ; done
                                break
                            else
                                sleep \${retry}
                            fi
                        done
                    else
                        nc -vz -w 2 ${ListenerIP} \${Ports}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-tcp.txt
                    fi
                done
                echo  "${TesterIP}-${ListenerIP}-tcp" >> ${REMOTESAVE}/${BlockName}-LocalReports/ActualDoneList
EOF
            [ -z ${UDPPorts} ] || cat <<EOF > ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-udp.sh
            #!/bin/bash
            FWStatus=\$(sudo systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            [ \${FWStatus} = active ] && sudo systemctl stop firewalld && echo 'sudo systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            mkdir -p ${REMOTESAVE}/${BlockName}-LocalReports
            touch ${REMOTESAVE}/${BlockName}-LocalReports/ActualDoneList
            for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
            do
                echo "\${Ports}"|grep -q '-'
                exit_status=\$?
                if [ \${exit_status} -eq 0 ] 
                then
                    Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                    End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                    for retry in \$(seq 1 ${ListentDurationInMinutes})
                    do    
                            nc -uz -w 2 ${ListenerIP} \${End_Port} &> /dev/null
                            exit_status=\$?
                            if [ \${exit_status} -eq 0 ]
                            then        
                                for Port in \$(seq \${Start_Port} \${End_Port}) ; do nc -vuz -w 2 ${ListenerIP} \${Port}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt ; done
                                break
                            else
                                sleep \$retry
                            fi
                    done
                else
                    nc -vuz -w 2 ${ListenerIP} \${Ports}   &>> ${REMOTESAVE}/${BlockName}-LocalReports/${TesterIP}-${ListenerIP}-udp.txt
                fi
            done
            echo  "${TesterIP}-${ListenerIP}-udp" >> ${REMOTESAVE}/${BlockName}-LocalReports/ActualDoneList
EOF
}
Generate_Collect_Reports () {
cat <<EOF > ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}.sh
until [ "\$(sort -n ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-ExpectedDoneList)" = "\$(sort -n ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-ActualDoneList)" ]
do
    sleep $(expr ${ListentDurationInMinutes} \* 6 ) 
    scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalReports/ActualDoneList ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-ActualDoneList 
done
scp -rP ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalReports ${LOCALSAVE}/${BlockName}-Reports/${TesterIP}
EOF
}
######################Start######################
#essential Validation 
#validate linux shell
[ $(uname -s) != "Linux" ] && Raise_Error 1
#validate no duplicate BlockNames/BlockAttributesNames
for BlockName in ${BlocksNames}
do
    [ $(echo "${BlocksNames}"|grep ${BlockName} | wc -l)  !=  1 ] && Raise_Error 2
done
for BlockName in ${BlocksNames}
do
    BlockContent=$(echo "${ConfFileContent}" | sed  -n  /${BlockName}/,/EOB/p | sed /EOB/d |sed /${BlockName}\/d)
    BlockAttributesNames=$(echo "${BlockContent}"| grep ':'|cut -d':' -f1)
    for BlockAttributeName in ${BlockAttributesNames}
    do
        [ $(echo "${BlockAttributesNames}"|grep ${BlockAttributeName} | wc -l)  !=  1 ] && Raise_Error 3
    done
done
#make sure the current host have nc/at
Validate_Install_Dependencies &> /dev/null
#write to $CONFPATH
echo -e "1 - start writing a consistent configuration file"
mkdir -p ${LOCALSAVE}
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
                        Raise_Error 4 ${BlockAttributeName} "can not be provided to the Default Block"
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
                        Raise_Error 4 ${BlockAttributeName} "invalide attribute name"
					    ;;
				esac
			done
		    ;;
	esac
done
echo -e "2 - configuration file created at\033[0;32m  ${CONFPATH} \033[0m "
# Check If Blocks fulfilled with needed attributes
# default value can fill missing mode/user/listen duration attributes
echo -e "3 - checks for blocks attributes keys started" 
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
                    Raise_Error 5  ${BlockAttributeName} "Have to be specified, there is no default value"
				fi
			fi
		done
# {tcp/udp}ports one of them must existe
# uni mode requires listeners/testers ips and bi require ips
        unset Mode
		Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
		case ${Mode} in
			bi)
				egrep -q "${BlockName}_TestersIPs|${BlockName}_ListenersIPs" ${CONFPATH} &&	Raise_Error 5 "TestersIPs/ListenersIPs" "bi mode should not have TestersIPs/ListenersIPs"
				grep -q "${BlockName}_IPs" ${CONFPATH} || Raise_Error 4 "IPs" "bi mode should have IPs"
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" ${CONFPATH} || Raise_Error 4  "TCPPorts/UDPPorts" "at least one should be specified "
			    ;;
			uni)
				grep -q "${BlockName}_IPs" ${CONFPATH} &&	Raise_Error 5 "IPs" "uni mode should not have IPs"
				grep -q "${BlockName}_TestersIPs" ${CONFPATH}  || Raise_Error 4 "TestersIPs" "bi mode should have TestersIPs"
				grep -q "${BlockName}_ListenersIPs" ${CONFPATH} || Raise_Error 4 "ListenersIPs" "bi mode should have IPs ListenersIPs"
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" ${CONFPATH} || Raise_Error 4 "TCPPorts/UDPPorts" "at least one should be specified "
			    ;;
			*)
                Raise_Error 4 ${Mode} "mode should be uni/bi"
			    ;;
		esac
	fi
done
echo -e "4 - Conf File \033[0;32m  ${CONFPATH} \033[0m has a valid attributes keys" 
#validate the attributes values
#modes values  already validated in previous check
#ListentDurationInMinutes  value must be an integer
#ips match ips regex
#ports intger from 0 - 65536
#validate remote ips ssh access and sudo no passwd privilege

echo -e "5 - validate attributes values started"

for BlockName in ${BlocksNames}
do  
    grep -q ${BlockName}_TCPPorts ${CONFPATH}	 	&&  TCPPorts=$( grep ${BlockName}_TCPPorts ${CONFPATH}|cut -d ':' -f2 ) 		&& Validate_Ports ${TCPPorts} TCPPorts
    grep -q ${BlockName}_UDPPorts ${CONFPATH} 		&&  UDPPorts=$( grep ${BlockName}_UDPPorts ${CONFPATH}|cut -d ':' -f2 ) 		&& Validate_Ports ${UDPPorts} UDPPorts
    grep -q ${BlockName}_IPs ${CONFPATH} 			&&  IPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d ':' -f2) 					&& Validate_IPS ${IPs}  IPs
    grep -q ${BlockName}_TestersIPs ${CONFPATH} 	&&  TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d ':' -f2)		&& Validate_IPS ${TestersIPs} TestersIPs
    grep -q ${BlockName}_ListenersIPs ${CONFPATH} 	&&  ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d ':' -f2)	&& Validate_IPS ${ListenersIPs} ListenersIPs
    grep -q ${BlockName}_ListentDurationInMinutes ${CONFPATH} 	&& 	ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d ':' -f2) && Validate_ListentDurationInMinutes ${ListentDurationInMinutes} ListentDurationInMinutes
    if [ ${BlockName} != Default ]
    then 
        unset User  Mode IPs TestersIPs ListenersIPs Expanded_TestersIPs Expanded_ListenersIPs
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && ListenersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        if [ ${Mode} = uni ]
        then
            expand_ips "ListenersIPs:${ListenersIPs}"
            expand_ips "TestersIPs:${TestersIPs}"
            for ListenerIP in ${Expanded_ListenersIPs}
            do 
                Validate_Access ${ListenerIP} 
                 ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} "$(typeset -f Validate_Install_Dependencies);   Validate_Install_Dependencies" &> /dev/null
            done
            for TesterIP in ${Expanded_TestersIPs}
            do 
                Validate_Access ${TesterIP}
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${TesterIP} "$(typeset -f Validate_Install_Dependencies);   Validate_Install_Dependencies" &> /dev/null

            done
        else
            expand_ips "ListenersIPs:${ListenersIPs}"
            for ListenerIP in ${Expanded_ListenersIPs}
            do
                Validate_Access ${ListenerIP}
                ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} "$(typeset -f Validate_Install_Dependencies);   Validate_Install_Dependencies" &> /dev/null

            done
        fi
    fi
done
echo -e "6 - all attributes keys at \033[0;32m  ${CONFPATH} \033[0m have valid values"
echo -e "7 - start create/execute Testers and Listeners Scripts"
#create listeners/testers scripts and execute them remotly and create a local task to check if any report finished every 10 minutes and aggregate them
for BlockName in ${BlocksNames}
do
    if [ ${BlockName} != Default ]
    then 
        echo -e "\tcreate/execute listener/testers script for \033[0;32m${BlockName}\033[0m:"
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts Expanded_TestersIPs Expanded_ListenersIPs
        mkdir -p ${LOCALSAVE}/${BlockName}-Scripts/{Listeners,Testers}/
        mkdir -p ${LOCALSAVE}/${BlockName}-Reports
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
            echo -e "\t\tListener:\033[0;32m ${ListenerIP} \033[0m "
            generate_listeners
            grep -q ${BlockName}_TCPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-tcp.sh &> /dev/null
            grep -q ${BlockName}_UDPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Listeners/${ListenerIP}-udp.sh &> /dev/null
            for TesterIP  in ${Expanded_TestersIPs}
            do
                echo -e "\t\t\tTester:\033[0;32m ${TesterIP}=>${ListenerIP} \033[0m"
                mkdir -p ${LOCALSAVE}/${BlockName}-ReportsGathering
                generate_testers
                grep -q ${BlockName}_TCPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-tcp.sh &> /dev/null
                grep -q ${BlockName}_UDPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/${BlockName}-Scripts/Testers/${TesterIP}-${ListenerIP}-udp.sh &> /dev/null
                if ! [ -z ${TCPPorts} ] 
                then
                    echo  "${TesterIP}-${ListenerIP}-tcp" >> ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-ExpectedDoneList
                fi
                if ! [ -z ${UDPPorts} ] 
                then
                    echo  "${TesterIP}-${ListenerIP}-udp" >> ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-ExpectedDoneList
                fi
            done
        done
        echo -e "\tcreate/execute listener/testers script for \033[0;32m${BlockName}\033[0m  finished"
    fi
done  
echo -e "8 - all testers/listeners scripts created/executed"
echo -e "9 - start reports gathering local tasks"       
for BlockName in ${BlocksNames}
do
    if [ ${BlockName} != Default ]
    then             
        echo -e " \033[0;32m${BlockName}\033[0m reports gathering , check interval is $(expr ${ListentDurationInMinutes} \* 6) seconds"
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d':' -f2)
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${User} = root ] &&  REMOTEHOME="/root" ||   REMOTEHOME="/home/${User}"
        REMOTESAVE="${REMOTEHOME}/CommsMatrix/${ConfFileName}-${ExecutionDate}"
        expand_ips "TestersIPs:${TestersIPs}"
        for TesterIP  in ${Expanded_TestersIPs}
        do
            echo -e "\t\t\033[0;32m  ${TesterIP} \033[0m reports will be saved once finished in\033[0;32m ${LOCALSAVE}/${BlockName}-Scripts/Testers/ \033[0m"
            touch ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-{ExpectedDoneList,ActualDoneList}
            scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTESAVE}/${BlockName}-LocalReports/ActualDoneList ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}-ActualDoneList/ &> /dev/null
            Generate_Collect_Reports &> /dev/null
            at -f ${LOCALSAVE}/${BlockName}-ReportsGathering/${TesterIP}.sh now &> /dev/null
        done
    fi
done
echo "10 - all reports gathering tasks created"