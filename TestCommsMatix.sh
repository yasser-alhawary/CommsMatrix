#!/bin/bash
unset ConfFileName ConfFileContent BlocksNames ExecutionDate LOCALSAVE CONFPATH
ConfFileName=${1##*/}
ConfFileContent=$(egrep -v '^$|^#' $1|tr -d ' '|sed 's/\[/EOB\n\[/g'|sed '1d'|sed -e '$a\EOB')
BlocksNames=$(echo "${ConfFileContent}" |grep '\['|tr -d '['|tr -d ']') 
ExecutionDate=$(date +"%Y_%m_%d_%I_%M_%S_%p")
LOCALSAVE="${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}"
CONFPATH="${LOCALSAVE}/${ConfFileName}"
mkdir -p ${LOCALSAVE}
echo -n > ${CONFPATH}
SSH_PORT=22
Listener_UDPScript="#! /usr/bin/python
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
[ $(uname -s) != Linux ] && echo "script does not support emulator,some expressions/commands will break" && exit 1
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
					echo port number ${Start_Port} is not an intger 
					exit 3
				elif ! [[ ${End_Port} == ?(-)+([0-9]) ]] 
                then
                    echo port number ${End_Port} is not an intger 
                    exit 3
				elif [ ${Start_Port} -lt 0 -o ${Start_Port} -gt 65536 -o ${End_Port} -lt 0 -o ${End_Port} -gt 65536 ]
				then
					echo port number should have value between 0 65536 , check port range ${Start_Port} to ${End_Port}
					exit 3
				elif [ ${Start_Port} -gt ${End_Port} ]
				then
					echo ${Start_Port} ${End_Port} is invalide port range
					exit 3
				fi
			else
				if ! [[ ${Ports} == ?(-)+([0-9]) ]] 
				then
					echo port number ${Ports} is not an intger 
					exit 3
				elif [ ${Ports} -lt 0 -o ${Ports} -gt 65536 ]
				then 
					echo invalid port specified ${Ports} , allowed values between 0 65536
					exit 3
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
                    echo ip ${IP} is not well formatted 
                    exit 3
                fi
            done
            if [ ${Start_IP_OCT1} -ne ${End_IP_OCT1} -o ${Start_IP_OCT2} -ne ${End_IP_OCT2} -o ${Start_IP_OCT3} -ne ${End_IP_OCT3} ]
            then
                echo not allowed ip range , only the right most octet in iprange can be different
                exit 3
            elif [ ${Start_IP_OCT4} -gt ${End_IP_OCT4} ]
            then 
                echo "ip range is not well formated, ${Start_IP_OCT4} is greater than ${End_IP_OCT4} "
                exit 3
            fi
		else 
			if ! [[ ${IPs} =~  ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
			then
				echo ip ${IPs} is not well formatted 
				exit 3
			fi
		fi
	done
}
Validate_ListentDurationInMinutes () {
			if [[ $1 == ?(-)+([0-9]) ]] 
			then
				if [[ $1 -eq 0 ]]
				then
				echo ListentDurationInMinutes $1 must be greater than 0
				exit 3
				fi
			else 
				echo ListentDurationInMinutes $1 is not an intger number 
				exit 3
			fi
}
Validate_Access(){
    nc -w 2 -z ${1} ${SSH_PORT} 
    exit_status=$?
    [ ${exit_status} -ne 0 ]  &&  echo "host ${1} is not ssh accessible , port ${SSH_PORT} is down" && exit 3

    ssh -q -p ${SSH_PORT}  -o PasswordAuthentication=no -o StrictHostKeyChecking=no ${User}@${1} sudo -vn &> /dev/null
    exit_status=$?
    if [ ${exit_status} -eq 1 ]
    then
        echo "${User} on ${1} is not a sudoer or sudoer password required " && exit 3
    elif [ ${exit_status} -eq 255 ]
    then
        echo "${User} on ${1} Does not Authorized the public key for ssh login" && exit 3
    elif [ ${exit_status} -ne 0 ]
    then
        echo "sudo access with no password is not satisified on host ${1} user ${User} " && exit 3
    fi
}
#2-Expand ips function and also exclude ips that are unreachable or is not root or sudoer nopasswd on it , logged
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
#3-Generate the listeners script function
generate_listeners () {
        [ -z ${TCPPorts} ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-tcp.sh
        #!/bin/bash
        FWStatus=\$(systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
        [ \${FWStatus} = active ] && systemctl stop firewalld && echo 'systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
        rpm -qa |grep -q nmap-ncat && yum install -y -q nmap-ncat 
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
                        echo "nc -4kl ${ListenerIP} \${Port}"|at now
                        PID=\$( pgrep -la nc|grep "${ListenerIP} \${Port}"|cut -d' ' -f1)
                        while [ -z \${PID} ] ; do   PID=\$( pgrep -la nc|grep "${ListenerIP} \${Port}"|cut -d' ' -f1) ; done
                        echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                    fi
                done
            else
                nc -w 2 -z ${ListenerIP} \${Ports}
                exit_status=\$?
                if [ \${exit_status} -ne 0 ]
                then
                    echo "nc -4kl ${ListenerIP} \${Ports}"|at now
                    PID=\$( pgrep -la nc|grep "${ListenerIP} \${Ports}"|cut -d' ' -f1)
                    while [ -z \${PID} ] ; do   PID=\$( pgrep -la nc|grep "${ListenerIP} \${Ports}"|cut -d' ' -f1) ; done
                    echo "kill -9 \${PID} "|at now +${ListentDurationInMinutes} minutes
                fi
            fi
        done
EOF
            [ -z ${UDPPorts} ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-udp.sh
            FWStatus=\$(systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            [ \${FWStatus} = active ] && systemctl stop firewalld && echo 'systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            rpm -qa |grep -q nmap-ncat || yum install -y -q nmap-ncat 
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
#generate the testers functions
generate_testers () {
                [ -z ${TCPPorts} ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-tcp.sh
                #!/bin/bash
                mkdir -p /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/
                mkdir -p \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/
                rpm -qa |grep -q nmap-ncat || yum install -y -q nmap-ncat 
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
                                for Port in \$(seq \${Start_Port} \${End_Port}) ; do nc -vz -w 2 ${ListenerIP} \${Port}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt ; done
                                break
                            else
                                sleep \${retry}
                            fi
                        done
                    else
                        nc -vz -w 2 ${ListenerIP} \${Ports}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt
                    fi
                done
                mv  /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt
EOF
            [ -z ${UDPPorts} ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-udp.sh
            #!/bin/bash
            mkdir -p /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/
            mkdir -p \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/
            rpm -qa |grep -q nmap-ncat || yum install -y -q nmap-ncat 
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
                                for Port in \$(seq \${Start_Port} \${End_Port}) ; do nc -vuz -w 2 ${ListenerIP} \${Port}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt ; done
                                break
                            else
                                sleep \$retry
                            fi
                    done
                else
                    nc -vuz -w 2 ${ListenerIP} \${Ports}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt
                fi
            done
            mv  /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt
EOF
}
###########Start###########
#write to $CONFPATH
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
                        #should be warning/ignore instead
						echo Not Allowed attribute name  ${BlockAttributeName} in conf file  ${ConfFileName} default block
						exit 1
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
                        #should be warning ignore
						echo Not Allowed attribute name  ${BlockAttributeName} in conf file  ${ConfFileName} block ${BlockName}
						exit 2
					    ;;
				esac
			done
		    ;;
	esac
done
# Check If Blocks fulfilled with needed attributes
# default value can fill missing mode/user/listen duration attributes
for BlockName in ${BlocksNames}
do
	if [ ${BlockName} != "Default" ]
	then 
		for Attribute in User Mode ListentDurationInMinutes
		do
			grep -q ${BlockName}_${Attribute} ${CONFPATH}
            exit_status=$? 
			if [ ${exit_status} -ne 0 ]
			then 
				grep -q Default_${Attribute} ${CONFPATH}
                exit_status=$?
				if [ ${exit_status} -eq 0 ]
				then
					echo "${BlockName}_${Attribute}:$(grep Default_${Attribute} ${CONFPATH}| cut -d':' -f2)" >> ${CONFPATH}
                else
					echo "Invalid Configuration No ${Attribute} set in ${BlockName} and there is no default one" && exit 2
				fi
			fi
		done
# {tcp/udp}ports one of them must existe
# uni mode requires listeners/testers ips and bi require ips
        unset Mode
		Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
		case ${Mode} in
			bi)
				egrep -q "${BlockName}_TestersIPs|${BlockName}_ListenersIPs" ${CONFPATH} &&	echo "Block ${BlockName} has Mode ${Mode} can not have either TestersIPs or ListenersIPs in the conf file"  && exit 2
				grep -q "${BlockName}_IPs" ${CONFPATH}
                exit_status=$?
				if [ ${exit_status} -ne 0 ]
				then
					echo "Block ${BlockName} is in ${Mode} Mode with no IPs Attribute specified" &&	exit 2
				fi
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" ${CONFPATH}
                exit_status=$?
				if [ ${exit_status} -ne -0 ]
				then
					echo "${BlockName} has no tcp or udp ports to test" &&	exit 2
				fi
			    ;;
			uni)
				grep -q "${BlockName}_IPs" ${CONFPATH} &&	echo Block ${BlockName} has Mode ${Mode} can not have IPs Attributes in the conf file && exit 2
				grep -q "${BlockName}_TestersIPs" ${CONFPATH} 
                exit_status=$?
				if [ ${exit_status} -ne 0 ]
				then 
					echo "Block ${BlockName} is in ${Mode} Mode with no TestersIps Attribute specified" && exit 2
				fi
				grep -q "${BlockName}_ListenersIPs" ${CONFPATH}
                exit_status=$?
				if [ ${exit_status} -ne 0 ]
				then 
					echo "Block ${BlockName} is in ${Mode} Mode with no ListenersIPs Attribute specified" && exit 2
				fi
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" ${CONFPATH}
                exit_status=$?
				if [ ${exit_status} -ne 0 ]
				then 
					echo "${BlockName} has no tcp or udp ports to test" &&	exit 2
				fi
			    ;;
			*)
				echo "No Valid Mode Specified ${Mode} for ${BlockName} Allowed Values are uni/bi"
				exit 2
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
for BlockName in ${BlocksNames}
do
    grep -q ${BlockName}_TCPPorts ${CONFPATH}	 	&&  TCPPorts=$( grep ${BlockName}_TCPPorts ${CONFPATH}|cut -d ':' -f2 ) 		&& Validate_Ports ${TCPPorts}
    grep -q ${BlockName}_UDPPorts ${CONFPATH} 		&&  UDPPorts=$( grep ${BlockName}_UDPPorts ${CONFPATH}|cut -d ':' -f2 ) 		&& Validate_Ports ${UDPPorts}
    grep -q ${BlockName}_IPs ${CONFPATH} 			&&  IPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d ':' -f2) 					&& Validate_IPS ${IPs}
    grep -q ${BlockName}_TestersIPs ${CONFPATH} 	&&  TestersIPs=$(grep ${BlockName}_TestersIPs${CONFPATH}|cut -d ':' -f2)		&& Validate_IPS ${TestersIPs}
    grep -q ${BlockName}_ListenersIPs ${CONFPATH} 	&&  ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d ':' -f2)	&& Validate_IPS ${ListenersIPs}
    grep -q ${BlockName}_ListentDurationInMinutes ${CONFPATH} 	&& 	ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d ':' -f2) && Validate_ListentDurationInMinutes ${ListentDurationInMinutes}
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
            done
            for TesterIP in ${Expanded_TestersIPs}
            do 
                Validate_Access ${TesterIP}
            done
        else
            expand_ips "ListenersIPs:${ListenersIPs}"
            for ListenerIP in ${Expanded_ListenersIPs}
            do
                Validate_Access ${ListenerIP}
            done
        fi
    fi
done
#create listeners/testers scripts and execute them remotly and create a local task to check if any report finished every 10 minutes and aggregate them
for BlockName in ${BlocksNames}
do
    if [ ${BlockName} != Default ]
    then 
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts Expanded_TestersIPs Expanded_ListenersIPs
        mkdir -p ${LOCALSAVE}/Scripts/${BlockName}/Listeners/
        User=$(grep ${BlockName}_User ${CONFPATH}|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes ${CONFPATH}|cut -d':' -f2)
        grep -q ${BlockName}_TCPPorts ${CONFPATH} &&  TCPPorts=$( grep ${BlockName}_TCPPorts ${CONFPATH}|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts ${CONFPATH} &&  UDPPorts=$( grep ${BlockName}_UDPPorts ${CONFPATH}|cut -d ':' -f2 )
        Mode=$(grep ${BlockName}_Mode ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && ListenersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs ${CONFPATH}|cut -d':' -f2)
        [ ${Mode} = bi ] && TestersIPs=$(grep ${BlockName}_IPs ${CONFPATH}|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs ${CONFPATH}|cut -d':' -f2)
        if [ ${User} = root ]
        then 
            REMOTE_HOME=/${User}
            ATCMD="at now"
        else
            REMOTE_HOME=/home/${User}
            ATCMD="sudo at now"
        fi
        #convert the input to spaced individual ips 
        expand_ips "ListenersIPs:${ListenersIPs}"
        expand_ips "TestersIPs:${TestersIPs}"
        # take the listener spaced ips and generate the scripts
        for ListenerIP in ${Expanded_ListenersIPs}
        do
            generate_listeners
            grep -q ${BlockName}_TCPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no  ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-tcp.sh &> /dev/null
            grep -q ${BlockName}_UDPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${ListenerIP} ${ATCMD} < ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-udp.sh &> /dev/null
            for TesterIP  in ${Expanded_TestersIPs}
            do
                mkdir -p ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/
                generate_testers
                grep -q ${BlockName}_TCPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-tcp.sh &> /dev/null
                grep -q ${BlockName}_UDPPorts ${CONFPATH} && ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}  ${ATCMD} < ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-udp.sh &> /dev/null
                if ! [ -z ${TCPPorts} ] 
                then
                    mkdir -p ${LOCALSAVE}/Reports/${BlockName}/${TesterIP}/tcp
                    echo "until \$(ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP} test -e ${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt);do sleep $(expr ${ListentDurationInMinutes} \* 6 ); done ; scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt ${LOCALSAVE}/Reports/${BlockName}/${TesterIP}/tcp/${TesterIP}-${ListenerIP}-tcp.txt"|at now &> /dev/null
                fi
                if ! [ -z ${UDPPorts} ] 
                then
                    mkdir -p ${LOCALSAVE}/Reports/${BlockName}/${TesterIP}/udp
                    echo "until \$(ssh -p ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP} test -e ${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt);do sleep $(expr ${ListentDurationInMinutes} \* 6 ); done ; scp -P ${SSH_PORT} -q -o StrictHostKeyChecking=no ${User}@${TesterIP}:${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt ${LOCALSAVE}/Reports/${BlockName}/${TesterIP}/udp/${TesterIP}-${ListenerIP}-udp.txt"|at now &> /dev/null
                fi
            done
        done
    fi
done