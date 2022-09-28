generate_testers () {
                [ -z $TCPPorts ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Testers/${TesterIP}/${TesterIP}-${ListenerIP}-tcp.sh
                #!/bin/bash
                mkdir -p /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/
                mkdir -p \${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/
                rpm -qa |grep -q nmap-ncat && yum install -y -q nmap-ncat 
                for Ports in \$(echo ${TCPPorts}|tr ',' ' ')
                do
                    echo "\${Ports}"|grep -q '-'
                    if [ \$? -eq 0 ] 
                    then
                        Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
                        End_Port=\$(echo \${Ports}|cut -d '-' -f2)
                        for retry in 1 2 3
                        do
                            nc -z -w 2 ${ListenerIP} \${End_Port} &> /dev/null
                            if [ \$? -eq 0 ]
                            then        
                                for port in \$(seq \${Start_Port} \${End_Port})
                                do
                                    nc -vz -w 2 ${ListenerIP} \${port}   &>> /tmp/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/tcp/${TesterIP}-${ListenerIP}.txt
                                done
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
#            [ -z $UDPPorts ] || cat <<EOF > ${LOCALSAVE}/Scripts/${BlockName}/Listeners/${ListenerIP}-udp.sh
#            #!/bin/bash
#            mkdir -p \${PWD}/CommsMatrix/${ConfFileName}/${ExecutionDate}/Reports/udp/
#FWStatus=\$(systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
#[ \$FWStatus = active ] && systemctl stop firewalld && echo 'systemctl start firewalld ' |at now +${ListentDurationInMinutes} minutes
#rpm -qa |grep -q nmap-ncat && yum install -y -q nmap-ncat 
#for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
#do
#    ListenFor=$ListentDurationInSeconds  
#    echo "\${Ports}"|grep -q '-'
#    if [ \$? -eq 0 ] 
#    then
#        Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
#        End_Port=\$(echo \${Ports}|cut -d '-' -f2)
#        for Port in \$(seq \${Start_Port} \${End_Port})
#        do
#            echo '' |nc -u -w 2 ${ListenerIP} \$Port
#            if [ \$? -ne 0 ]
#            then
#                SECONDS=0
#                echo "while (( SECONDS < ListenFor )) ; do nc -4lu -i 0.001 ${ListenerIP} \${Port} ; done "|at now
#            fi
#        done
#    else
#        echo ''|nc -u -w 2 ${ListenerIP} \$Ports
#        if [ \$? -ne 0 ]
#        then
#            SECONDS=0
#            echo "while (( SECONDS < ListenFor )) ; do nc -4lu -i 0.001 ${ListenerIP} \${Ports} ; done"|at now
#        fi
#    fi
#done
#                touch Reports/udp/done
#EOF
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