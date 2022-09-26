systemctl stop firewalld 
yum install -y nmap-ncat 
systemctl start atd
for Ports in $(echo 100-101,200,200-2100|tr ',' ' ')
do
Start_Port=$(echo ${Ports}|cut -d '-' -f1)
End_Port=$(echo ${Ports}|cut -d '-' -f2)
for Port in $(seq ${Start_Port} ${End_Port})
do
echo "nc -kl 7.7.7.7,8.8.8.8 ${Port}"|at now
done
done
echo pkill -f nc|at now +10 minutes
