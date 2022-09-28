#!/bin/bash
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
            rpm -qa |grep -q nmap-ncat && yum install -y -q nmap-ncat 
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
