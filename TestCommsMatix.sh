#!/bin/bash
ConfFileName=${1##*/}
ExecutionDate=$(date +"%Y_%m_%d_%I_%M_%S_%p")
LOCALSAVE="${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}"
CONFPATH="$LOCALSAVE/${ConfFileName}"
mkdir -p $LOCALSAVE
echo -n > $CONFPATH
#Create the UDP Listener python script to be send to remtote listeners if not exist
cat <<EOF > /tmp/UDP-Listener.py
#! /usr/bin/python
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
    message, ipport = sock.recvfrom(bufSize)
EOF
ConfFileContent=$(egrep -v '^$|^#' $1|tr -d ' '|sed 's/\[/EOB\n\[/g'|sed '1d'|sed -e '$a\EOB')
BlocksNames=$(echo "${ConfFileContent}" |grep '\['|tr -d '['|tr -d ']') 
#array/dicts are not flexible and bash prohibt nest substitutin so save will be file based
#parse and save to the $CONFPATH
for BlockName in ${BlocksNames}
do
	BlockContent=$(echo "${ConfFileContent}" | sed  -n  /$BlockName/,/EOB/p | sed /EOB/d |sed /$BlockName\/d)
	BlockAttributesNames=$(echo "${BlockContent}"| grep ':'|cut -d':' -f1)
	case $BlockName in 
		Default)
			for BlockAttributeName in ${BlockAttributesNames}
			do
				case $BlockAttributeName in
					User|Mode|ListentDurationInMinutes)
						BlockAttributeContent=$(echo "${BlockContent}"|grep -i $BlockAttributeName|cut -d':' -f2)
						case $BlockAttributeName in
							User)
								echo "Default_User:$BlockAttributeContent" >> $CONFPATH
							;;
							Mode)
								echo "Default_Mode:$BlockAttributeContent" >> $CONFPATH
							;;
							ListentDurationInMinutes)
								echo "Default_ListentDurationInMinutes:$BlockAttributeContent" >> $CONFPATH
							;;
						esac
					;;
					*)
						echo Not Allowed attribute name  $BlockAttributeName in conf file  $ConfFileName default block
						exit 1
					;;
				esac
			done
		;;
		*)
			for BlockAttributeName in ${BlockAttributesNames}
			do
				case $BlockAttributeName in
					User|Mode|ListentDurationInMinutes|TCPPorts|UDPPorts|IPs|TestersIPs|ListenersIPs)
						case $BlockAttributeName in
							User|Mode|ListentDurationInMinutes|TCPPorts|UDPPorts)
							BlockAttributeContent=$(echo "${BlockContent}"|grep -i $BlockAttributeName|cut -d':' -f2)
							case $BlockAttributeName in
								User)
									echo "${BlockName}_User:$BlockAttributeContent" >> $CONFPATH
								;;
								Mode)
									echo "${BlockName}_Mode:$BlockAttributeContent" >> $CONFPATH
								;;
								ListentDurationInMinutes)
									echo "${BlockName}_ListentDurationInMinutes:$BlockAttributeContent" >> $CONFPATH
								;;
								TCPPorts)
									echo "${BlockName}_TCPPorts:$BlockAttributeContent" >> $CONFPATH
								;;
								UDPPorts)
									echo "${BlockName}_UDPPorts:$BlockAttributeContent" >> $CONFPATH
								;;
							esac
							;;
							*)
								BlockAttributeContent=$(echo "${BlockContent}"|sed -n "/$BlockAttributeName/,/^[A-Za-z]/p"|grep -v ':'|tr '\n' ','|rev|cut -c2-|rev)
								case $BlockAttributeName in
									IPs)
										echo "${BlockName}_IPs:$BlockAttributeContent" >> $CONFPATH
									;;
									TestersIPs)
										echo "${BlockName}_TestersIPs:$BlockAttributeContent" >> $CONFPATH
									;;
									ListenersIPs)
										echo "${BlockName}_ListenersIPs:$BlockAttributeContent" >> $CONFPATH
									;;
								esac
							;;
						esac
					;;
					*)
						echo Not Allowed attribute name  $BlockAttributeName in conf file  $ConfFileName block $BlockName
						exit 2
					;;
				esac
			done
		;;
	esac
done
#Check If Attributes is not fulfilled properly
for BlockName in ${BlocksNames}
do
	if [ $BlockName != "Default" ]
	then 
		for Att in User Mode ListentDurationInMinutes
		do
			grep -q ${BlockName}_${Att} $CONFPATH 
			if [ $? -ne 0 ]
			then 
				grep -q Default_${Att} $CONFPATH
				if [ $? -eq 0 ]
				then
					echo "${BlockName}_${Att}:$(grep Default_${Att} $CONFPATH| cut -d':' -f2)" >> $CONFPATH
				elif [$? -ne 0 ]
				then
					echo "Invalid Configuration No $Att set in ${BlockName} and there is no default one" && exit 2
				fi
			fi
		done
		Mode=$(grep ${BlockName}_Mode $CONFPATH|cut -d':' -f2)
		case $Mode in
			bi)
				egrep -q "${BlockName}_TestersIPs|${BlockName}_ListenersIPs" $CONFPATH &&	echo "Block $BlockName has Mode $Mode can not have either TestersIPs or ListenersIPs in the conf file"  && exit 2
				grep -q "${BlockName}_IPs" $CONFPATH
				if [ $? -ne 0 ]
				then
					echo "Block $BlockName is in $Mode Mode with no IPs Attribute specified" &&	exit 2
				fi
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" $CONFPATH
				if [ $? -ne -0 ]
				then
					echo "$BlockName has no tcp or udp ports to test" &&	exit 2
				fi
			;;
			uni)
				grep -q "${BlockName}_IPs" $CONFPATH &&	echo Block $BlockName has Mode $Mode can not have IPs Attributes in the conf file && exit 2
				grep -q "${BlockName}_TestersIPs" $CONFPATH 
				if [ $? -ne 0 ]
				then 
					echo "Block $BlockName is in $Mode Mode with no TestersIps Attribute specified" && exit 2
				fi
				grep -q "${BlockName}_ListenersIPs" $CONFPATH
				if [ $? -ne 0 ]
				then 
					echo "Block $BlockName is in $Mode Mode with no ListenersIPs Attribute specified" && exit 2
				fi
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" $CONFPATH
				if [ $? -ne 0 ]
				then 
					echo "$BlockName has no tcp or udp ports to test" &&	exit 2
				fi
			;;
			*)
				echo "No Valid Mode Specified $Mode for $BlockName Allowed Values are uni/bi"
				exit 2
			;;
		esac
	fi
done

#####
Validate_Ports() {
	for Ports in $(echo $1|tr ',' ' ')
		do
			echo $Ports|grep -q '-'
			if [ $? -eq 0 ]
			then
				Start_Port=$(echo $Ports|cut -d '-' -f1 )
				End_Port=$(echo $Ports|cut -d '-' -f2 )
				if ! [[ $Start_Port == ?(-)+([0-9]) ]] 
				then
					echo port number $start_port is not an intger 
					exit 3
				fi
				if ! [[ $End_Port == ?(-)+([0-9]) ]] 
				then
					echo port number $End_Port is not an intger 
					exit 3
				fi
				if [ $Start_Port -lt 0 -o $Start_Port -gt 65536 -o $End_Port -lt 0 -o $End_Port -gt 65536 ]
				then
					echo port number should have value between 0 65536 , check port range $Start_Port to $End_Port
					exit 3
				else
					if [ $Start_Port -gt $End_Port ]
					then
						echo $Start_Port $End_Port is invalide port range
						exit 3
					fi
				fi
			else
				if ! [[ $Ports == ?(-)+([0-9]) ]] 
				then
					echo port number $Ports is not an intger 
					exit 3
				fi
				if [ $Ports -lt 0 -o $Ports -gt 65536 ]
				then 
					echo invalid port specified $Ports , allowed values between 0 65536
					exit 3
				fi
			fi
		done
}

Validate_IPS () {
	for IPs in $(echo $1|tr ',' ' ')
	do
		echo $IPs|grep -q '-'
		if [ $? -eq 0 ]
		then
				Start_IP=$(echo $IPs|cut -d '-' -f1 )
				End_IP=$(echo $IPs|cut -d '-' -f2 )
				for ipaddress in $Start_IP $End_IP
				do
					if ! [[ $ipaddress =~  ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
					then
						echo ip $ipaddress is not well formatted 
						exit 3
					fi
				done
				Start_IP_OCT1=$(echo $Start_IP|cut -d'.' -f1)
				Start_IP_OCT2=$(echo $Start_IP|cut -d'.' -f2)
				Start_IP_OCT3=$(echo $Start_IP|cut -d'.' -f3)
				Start_IP_OCT4=$(echo $Start_IP|cut -d'.' -f4)
				End_IP_OCT1=$(echo $End_IP|cut -d'.' -f1)
				End_IP_OCT2=$(echo $End_IP|cut -d'.' -f2)
				End_IP_OCT3=$(echo $End_IP|cut -d'.' -f3)
				End_IP_OCT4=$(echo $End_IP|cut -d'.' -f4)
				if [ $Start_IP_OCT1 -ne $End_IP_OCT1 -o $Start_IP_OCT2 -ne $End_IP_OCT2 -o $Start_IP_OCT3 -ne $End_IP_OCT3 ]
				then
					echo not allowed ip range , only the right most octet in iprange can be different
					exit 3
				fi
				if [ $Start_IP_OCT4 -gt $End_IP_OCT4 ]
				then 
					echo "ip range is not well formated, $Start_IP_OCT4 is greater than $End_IP_OCT4 "
					exit 3
				fi
		else 
			if ! [[ ${IPs} =~  ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]
			then
				echo ip $IPs is not well formatted 
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
#Validate IPS/Ports/wait Values
for BlockName in ${BlocksNames}
do
	    grep -q ${BlockName}_TCPPorts $CONFPATH	 	&&  TCPPorts=$( grep ${BlockName}_TCPPorts $CONFPATH|cut -d ':' -f2 ) 		&& Validate_Ports $TCPPorts
        grep -q ${BlockName}_UDPPorts $CONFPATH 		&&  UDPPorts=$( grep ${BlockName}_UDPPorts $CONFPATH|cut -d ':' -f2 ) 		&& Validate_Ports $UDPPorts
		grep -q ${BlockName}_IPs $CONFPATH 			&&  IPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d ':' -f2) 					&& Validate_IPS $IPs
		grep -q ${BlockName}_TestersIPs $CONFPATH 	&&  TestersIPs=$(grep ${BlockName}_TestersIPs $CONFPATH|cut -d ':' -f2)		&& Validate_IPS $TestersIPs
        grep -q ${BlockName}_ListenersIPs $CONFPATH 	&&  ListenersIPs=$(grep ${BlockName}_ListenersIPs $CONFPATH|cut -d ':' -f2)	&& Validate_IPS $ListenersIPs
		grep -q ${BlockName}_ListentDurationInMinutes $CONFPATH 	&& 	ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes $CONFPATH|cut -d ':' -f2) && Validate_ListentDurationInMinutes $ListentDurationInMinutes
done
Expand_ListenersIPs() {
    unset Expanded_ListenersIPs
    for IPRange in $(echo $1|tr ',' ' ')
    do
        echo $IPRange|grep -q '-'
        if [ $? -eq 0 ]
        then
                Start_IP=$(echo $IPRange|cut -d '-' -f1 )
                End_IP=$(echo $IPRange|cut -d '-' -f2 )
                Start_IP_OCT1=$(echo $Start_IP|cut -d'.' -f1)
                Start_IP_OCT2=$(echo $Start_IP|cut -d'.' -f2)
                Start_IP_OCT3=$(echo $Start_IP|cut -d'.' -f3)
                Start_IP_OCT4=$(echo $Start_IP|cut -d'.' -f4)
                End_IP_OCT1=$(echo $End_IP|cut -d'.' -f1)
                End_IP_OCT2=$(echo $End_IP|cut -d'.' -f2)
                End_IP_OCT3=$(echo $End_IP|cut -d'.' -f3)
                End_IP_OCT4=$(echo $End_IP|cut -d'.' -f4)
                for IP in $(seq ${Start_IP_OCT4} ${End_IP_OCT4})
                do
                    Expanded_ListenersIPs="$Expanded_ListenersIPs ${Start_IP_OCT1}.${Start_IP_OCT2}.${Start_IP_OCT3}.${IP}"
                done
        else
                    Expanded_ListenersIPs="$Expanded_ListenersIPs $IPRange"
        fi
    done
}
Expand_TestersIPs() {
    unset Expanded_TestersIPs
    for IPRange in $(echo $1|tr ',' ' ')
    do
        echo $IPRange|grep -q '-'
        if [ $? -eq 0 ]
        then
                Start_IP=$(echo $IPRange|cut -d '-' -f1 )
                End_IP=$(echo $IPRange|cut -d '-' -f2 )
                Start_IP_OCT1=$(echo $Start_IP|cut -d'.' -f1)
                Start_IP_OCT2=$(echo $Start_IP|cut -d'.' -f2)
                Start_IP_OCT3=$(echo $Start_IP|cut -d'.' -f3)
                Start_IP_OCT4=$(echo $Start_IP|cut -d'.' -f4)
                End_IP_OCT1=$(echo $End_IP|cut -d'.' -f1)
                End_IP_OCT2=$(echo $End_IP|cut -d'.' -f2)
                End_IP_OCT3=$(echo $End_IP|cut -d'.' -f3)
                End_IP_OCT4=$(echo $End_IP|cut -d'.' -f4)
                for IP in $(seq ${Start_IP_OCT4} ${End_IP_OCT4})
                do
                    Expanded_TestersIPs="$Expanded_TestersIPs ${Start_IP_OCT1}.${Start_IP_OCT2}.${Start_IP_OCT3}.${IP}"
                done
        else
                    Expanded_TestersIPs="$Expanded_TestersIPs $IPRange"
        fi
    done
}
generate_listeners () {
        [ -z $TCPPorts ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${1}-tcp.sh
        #!/bin/bash
        FWStatus=\$(systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
        [ \$FWStatus = active ] && systemctl stop firewalld && echo 'systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
        rpm -qa |grep -q nmap-ncat && yum install -y -q nmap-ncat 
        for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
        do
            echo "\${Ports}"|grep -q '-'
            if [ \$? -eq 0 ] 
            then
                Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                for Port in \$(seq \${Start_Port} \${End_Port})
                do
                    nc -w 2 -z ${1} \$Port
                    if [ \$? -ne 0 ]
                    then
                        echo "nc -4kl ${1} \${Port}"|at now
                        PID=\$( pgrep -la nc|grep "${1} \${Port}"|cut -d' ' -f1)
                        while [ -z \$PID ] ; do   PID=\$( pgrep -la nc|grep "${1} \${Port}"|cut -d' ' -f1) ; done
                        echo "kill -9 \$PID "|at now +${ListentDurationInMinutes} minutes
                    fi
                done
            else
                nc -w 2 -z ${1} \$Ports
                if [ \$? -ne 0 ]
                then
                    echo "nc -4kl ${1} \${Ports}"|at now
                    PID=\$( pgrep -la nc|grep "${1} \${Ports}"|cut -d' ' -f1)
                    while [ -z \$PID ] ; do   PID=\$( pgrep -la nc|grep "${1} \${Ports}"|cut -d' ' -f1) ; done
                    echo "kill -9 \$PID "|at now +${ListentDurationInMinutes} minutes
                fi
            fi
        done
EOF
            [ -z $UDPPorts ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${1}-udp.sh
            FWStatus=\$(systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
            [ \$FWStatus = active ] && systemctl stop firewalld && echo 'systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
            rpm -qa |grep -q nmap-ncat || yum install -y -q nmap-ncat 
            for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
            do
                echo "\${Ports}"|grep -q '-'
                if [ \$? -eq 0 ] 
                then
                    Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                    End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                    for Port in \$(seq \${Start_Port} \${End_Port})
                    do
                        nc -uz -w 2 ${1} \$Port
                        if [ \$? -ne 0 ]
                        then
                                echo "python /tmp/UDP-Listener.py ${1} \${Port}"|at now
                                unset PID
                                PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${1} \${Port}"|cut -d' ' -f1)
                                while [ -z \$PID ] ; do PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${1} \${Port}"|cut -d' ' -f1) ; done
                                echo "kill -9 \$PID "|at now +${ListentDurationInMinutes} minutes
                        fi
                    done
                else
                    nc -uz -w 2 ${1} \$Ports
                    if [ \$? -ne 0 ]
                    then
                        echo "python /tmp/UDP-Listener.py ${1} \${Ports}"|at now
                        unset PID
                        PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${1} \${Ports}"|cut -d' ' -f1)
                        while [ -z \$PID ] ; do PID=\$(pgrep -la python|grep "/tmp/UDP-Listener.py ${1} \${Ports}"|cut -d' ' -f1) ; done
                        echo "kill -9 \$PID "|at now +${ListentDurationInMinutes} minutes
                    fi
                fi
            done
EOF
}
for BlockName in $BlocksNames
do
    if [ $BlockName != Default ]
    then 
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts 
        mkdir -p ${LOCALSAVE}/Scripts/${BlockName}/Listeners/
        Mode=$(grep ${BlockName}_Mode $CONFPATH|cut -d':' -f2)
        User=$(grep ${BlockName}_User $CONFPATH|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes $CONFPATH|cut -d':' -f2)
        ListentDurationInSeconds=$( expr $ListentDurationInMinutes \* 60 )
        grep -q ${BlockName}_TCPPorts $CONFPATH &&  TCPPorts=$( grep ${BlockName}_TCPPorts $CONFPATH|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts $CONFPATH &&  UDPPorts=$( grep ${BlockName}_UDPPorts $CONFPATH|cut -d ':' -f2 )
        [ $Mode = bi ] && ListenersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs $CONFPATH|cut -d':' -f2)
        #convert the input spaced individual ips 
        Expand_ListenersIPs "${ListenersIPs}"
        # take the listener spaced ips and generate the scripts
        for ListenerIP in ${Expanded_ListenersIPs}
        do
            ssh -q $User@${Listener} test -e /tmp/UDP-Listener.py || scp /tmp/UDP-Listener.py ${User}@${ListenerIP}:/tmp/  &>/dev/null 
            generate_listeners "${ListenerIP}"
        done
    fi
done 

generate_testers () {
                [ -z $TCPPorts ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-tcp.sh
                #!/bin/bash
                mkdir -p /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/
                mkdir -p \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/
                rpm -qa |grep -q nmap-ncat || yum install -y -q nmap-ncat 
                for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
                do
                    echo "\${Ports}"|grep -q '-'
                    if [ \$? -eq 0 ] 
                    then
                        Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                        End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                        for retry in \$(seq 1 ${ListentDurationInMinutes})
                        do
                            nc -z -w 2 ${ListenerIP} \${End_Port} &> /dev/null
                            if [ \$? -eq 0 ]
                            then        
                                for Port in \$(seq \${Start_Port} \${End_Port}) ; do nc -vz -w 2 ${ListenerIP} \${Port}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt ; done
                                break
                            else
                                sleep \$retry
                            fi
                        done
                    else
                        nc -vz -w 2 ${ListenerIP} \${Ports}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt
                    fi
                done
                mv  /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt
EOF
            [ -z $UDPPorts ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-udp.sh
            #!/bin/bash
            mkdir -p /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/
            mkdir -p \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/
            rpm -qa |grep -q nmap-ncat || yum install -y -q nmap-ncat 
            for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
            do
                echo "\${Ports}"|grep -q '-'
                if [ \$? -eq 0 ] 
                then
                    Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                    End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                    for retry in \$(seq 1 $ListentDurationInMinutes)
                    do    
                            nc -uz -w 2 ${ListenerIP} \${End_Port} &> /dev/null
                            if [ \$? -eq 0 ]
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
for BlockName in $BlocksNames
do
    if [ $BlockName != Default ]
    then 
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts 
        Mode=$(grep ${BlockName}_Mode $CONFPATH|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes $CONFPATH|cut -d':' -f2)
        ListentDurationInSeconds=$( expr $ListentDurationInMinutes \* 60 )
        grep -q ${BlockName}_TCPPorts $CONFPATH &&  TCPPorts=$( grep ${BlockName}_TCPPorts $CONFPATH|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts $CONFPATH &&  UDPPorts=$( grep ${BlockName}_UDPPorts $CONFPATH|cut -d ':' -f2 )
        [ $Mode = bi ] && TestersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs $CONFPATH|cut -d':' -f2)
        [ $Mode = bi ] && ListenersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs $CONFPATH|cut -d':' -f2)
        #convert the input spaced individual ips 
        Expand_ListenersIPs "${ListenersIPs}"
        Expand_TestersIPs "${TestersIPs}"
        # take the listener spaced ips and generate the scripts
        for TesterIP  in ${Expanded_TestersIPs}
        do
            mkdir -p ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/
            for ListenerIP in $Expanded_ListenersIPs
                do
                    generate_testers
                done            
        done
    fi
done 
for BlockName in $BlocksNames
do
    if [ $BlockName != Default ]
    then 
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts 
        Mode=$(grep ${BlockName}_Mode $CONFPATH|cut -d':' -f2)
        User=$(grep ${BlockName}_User $CONFPATH|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes $CONFPATH|cut -d':' -f2)
        ListentDurationInSeconds=$( expr $ListentDurationInMinutes \* 60 )
        grep -q ${BlockName}_TCPPorts $CONFPATH &&  TCPPorts=$( grep ${BlockName}_TCPPorts $CONFPATH|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts $CONFPATH &&  UDPPorts=$( grep ${BlockName}_UDPPorts $CONFPATH|cut -d ':' -f2 )
        [ $Mode = bi ] && ListenersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs $CONFPATH|cut -d':' -f2)
        [ $Mode = bi ] && TestersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs $CONFPATH|cut -d':' -f2)
        [ $User = root ] && REMOTE_HOME=/${User} || REMOTE_HOME=/home/${User}
        Expand_ListenersIPs "${ListenersIPs}"
        Expand_TestersIPs "${TestersIPs}"
        if [ $User = root ]
        then
            for ListenerIP in  ${Expanded_ListenersIPs}
            do
                    grep -q ${BlockName}_TCPPorts $CONFPATH && ssh -q ${USER}@${ListenerIP} at now < ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-tcp.sh &> /dev/null
                    grep -q ${BlockName}_UDPPorts $CONFPATH && ssh -q ${USER}@${ListenerIP} at now < ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-udp.sh &> /dev/null
                    for TesterIP  in ${Expanded_TestersIPs}
                        do
                            grep -q ${BlockName}_TCPPorts $CONFPATH && ssh -q ${USER}@${TesterIP} at now < ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-tcp.sh &> /dev/null
                            grep -q ${BlockName}_UDPPorts $CONFPATH && ssh -q ${USER}@${TesterIP} at now < ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-udp.sh &> /dev/null
                        done
            done
        else
            for ListenerIP in  ${Expanded_ListenersIPs}
            do
                        grep -q ${BlockName}_TCPPorts $CONFPATH && ssh -q ${USER}@${ListenerIP} sudo at now < ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-tcp.sh &> /dev/null
                        grep -q ${BlockName}_UDPPorts $CONFPATH && ssh -q ${USER}@${ListenerIP} sudo at now < ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-udp.sh &> /dev/null
                    for TesterIP  in ${Expanded_TestersIPs}
                        do
                            grep -q ${BlockName}_TCPPorts $CONFPATH && ssh -q ${USER}@${TesterIP} sudo at now < ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-tcp.sh &> /dev/null
                            grep -q ${BlockName}_UDPPorts $CONFPATH && ssh -q ${USER}@${TesterIP} sudo at now < ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-udp.sh &> /dev/null
                        done
            done
        fi
    fi
done
for BlockName in $BlocksNames
do
    if [ $BlockName != Default ]
    then 
        unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts 
        Mode=$(grep ${BlockName}_Mode $CONFPATH|cut -d':' -f2)
        User=$(grep ${BlockName}_User $CONFPATH|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes $CONFPATH|cut -d':' -f2)
        ListentDurationInSeconds=$( expr $ListentDurationInMinutes \* 60 )
        grep -q ${BlockName}_TCPPorts $CONFPATH &&  TCPPorts=$( grep ${BlockName}_TCPPorts $CONFPATH|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts $CONFPATH &&  UDPPorts=$( grep ${BlockName}_UDPPorts $CONFPATH|cut -d ':' -f2 )
        [ $Mode = bi ] && ListenersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || ListenersIPs=$(grep ${BlockName}_ListenersIPs $CONFPATH|cut -d':' -f2)
        [ $Mode = bi ] && TestersIPs=$(grep ${BlockName}_IPs $CONFPATH|cut -d':' -f2) || TestersIPs=$(grep ${BlockName}_TestersIPs $CONFPATH|cut -d':' -f2)
        [ $User = root ] && REMOTE_HOME=/${User} || REMOTE_HOME="/home/${User}"
        for ListenerIP  in ${Expanded_ListenersIPs}
        do
            for TesterIP  in ${Expanded_TestersIPs}
            do
                if ! [ -z $TCPPorts ] 
                then
                    mkdir -p ${LOCALSAVE}/Reports/${BlockName}/${TesterIP}/tcp
                    echo "until \$(ssh ${User}@${TesterIP} test -e ${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt);do sleep 10; done ; scp  ${User}@${TesterIP}:${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt $LOCALSAVE/Reports/${BlockName}/${TesterIP}/tcp/${TesterIP}-${ListenerIP}-tcp.txt"|at now

                fi
                if ! [ -z $UDPPorts ] 
                then
                    mkdir -p ${LOCALSAVE}/Reports/${BlockName}/${TesterIP}/udp
                    echo "until \$(ssh ${User}@${TesterIP} test -e ${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt);do sleep 10; done ; scp  ${User}@${TesterIP}:${REMOTE_HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/${TesterIP}-${ListenerIP}.txt $LOCALSAVE/Reports/${BlockName}/${TesterIP}/udp/${TesterIP}-${ListenerIP}-udp.txt"|at now
                fi
            done
        done
    fi
done