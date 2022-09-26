FWStatus=$(systemctl show -p ActiveState firewalld | sed 's/ActiveState=//g')
[ $FWStatus = active ] && systemctl stop firewalld && echo 'systemctl start firewalld ' |at now +10 minutes
rpm -qa |grep -q nmap-ncat && yum install -y -q nmap-ncat 
for Ports in $(echo 1,2|tr ',' ' ')
do
echo "${Ports}"|grep -q '-'
if [ $? -eq 0 ] 
then
Start_Port=$(echo ${Ports}|cut -d '-' -f1)
End_Port=$(echo ${Ports}|cut -d '-' -f2)
for Port in $(seq ${Start_Port} ${End_Port})
do
nc -w 2 -z 7.7.7.7,8.8.8.8 $Port
[ $? -ne 0 ]
then
echo "nc -4kl 7.7.7.7,8.8.8.8 ${Port}"|at now
echo "kill -9 "|at now +10 minutes
done
else
then
nc -w 2 -z 7.7.7.7,8.8.8.8 $Ports
[ $? -ne 0 ]
then
echo "nc -4kl 7.7.7.7,8.8.8.8 ${Ports}"|at now
echo "kill -9 "|at now +10 minutes
fi
done
