#!/bin/bash
for BlockName in $BlocksNames
do
    unset User ListentDurationInMinutes Mode IPs TestersIPs ListenersIPs TCPPorts UDPPorts 
    mkdir -p ${SAVEDIR}/${BlockName}/Scripts/Listeners/
    if [ $BlockName != Default ]
    then 
        Mode=$(grep ${BlockName}_Mode $TMPCONF|cut -d':' -f2)
        ListentDurationInMinutes=$(grep ${BlockName}_ListentDurationInMinutes $TMPCONF|cut -d':' -f2)
        grep -q ${BlockName}_TCPPorts $TMPCONF &&  TCPPorts=$( grep ${BlockName}_TCPPorts $TMPCONF|cut -d ':' -f2 )
        grep -q ${BlockName}_UDPPorts $TMPCONF &&  UDPPorts=$( grep ${BlockName}_UDPPorts $TMPCONF|cut -d ':' -f2 )
        case $Mode in 
            bi)
                IPs=$(grep ${BlockName}_IPs $TMPCONF|cut -d':' -f2)
                for IP in ${IPs} 
                do
                    [ -n $TCPPorts ] && cat <<EOF > ${SAVEDIR}/${BlockName}/Scripts/Listeners/${IP}-tcp.sh
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
nc -w 2 -z ${IP} \$Port
[ \$? -ne 0 ]
then
echo "nc -4kl ${IP} \${Port}"|at now
echo "kill -9 \$(ps -eo command,pid|grep "nc -4kl ${IP} \$Port"|tr ' ' '\n'|grep -v '^$'|tail -n 1)"|at now +${ListentDurationInMinutes} minutes
done
else
then
nc -w 2 -z ${IP} \$Ports
[ \$? -ne 0 ]
then
echo "nc -4kl ${IP} \${Ports}"|at now
echo "kill -9 \$(ps -eo command,pid|grep 'nc -4kl ${IP} \${Ports}'|tr ' ' '\n'|grep -v '^$'|tail -n 1)"|at now +${ListentDurationInMinutes} minutes
fi
done
EOF
                    [ -n $UDPPorts ] && cat <<EOF > ${SAVEDIR}/${BlockName}/Scripts/Listeners/${IP}-udp.sh
systemctl stop firewalld 
yum install -y nmap-ncat 
systemctl start atd
for Ports in \$(echo ${UDPPorts}|tr ',' ' ')
do
Start_Port=\$(echo \${Ports}|cut -d '-' -f1)
End_Port=\$(echo \${Ports}|cut -d '-' -f2)
for Port in \$(seq \${Start_Port} \${End_Port})
do
echo "nc -kl ${IP} \${Port}"|at now
done
done
echo pkill -f nc|at now +${ListentDurationInMinutes} minutes
EOF
            done
            ;;
            uni)
                TestersIPs=$(grep ${BlockName}_TestersIPs $TMPCONF|cut -d':' -f2)
                ListenersIPs=$(grep ${BlockName}_ListenersIPs $TMPCONF|cut -d':' -f2)
            ;;
        esac
    fi
done 