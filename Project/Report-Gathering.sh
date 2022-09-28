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
