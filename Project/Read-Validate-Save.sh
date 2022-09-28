ConfFileName=${1##*/}
ExecutionDate=$(date +"%Y_%m_%d_%I_%M_%S_%p")
LOCALSAVE="${HOME}/CommsMatrix/${ConfFileName}/${ExecutionDate}"
CONFPATH="$LOCALSAVE/${ConfFileName}"
mkdir -p $LOCALSAVE
echo -n > $CONFPATH
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