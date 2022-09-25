ConfFileName=${1##*/}
ExecutionDate=$(date +"%Y_%m_%d_%I_%M_%p")
TMPCONF="/tmp/${ConfFileName}-${ExecutionDate}.conf"
echo -n > $TMPCONF
ConfFileContent=$(egrep -v '^$|^#' $1|tr -d ' '|sed 's/\[/EOB\n\[/g'|sed '1d'|sed -e '$a\EOB')
BlocksNames=$(echo "${ConfFileContent}" |grep '\['|tr -d '['|tr -d ']') 
#array/dicts are not flexible and bash prohibt nest substitutin so save will be file based
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
								echo "Default_User:$BlockAttributeContent" >> $TMPCONF
							;;
							Mode)
								echo "Default_Mode:$BlockAttributeContent" >> $TMPCONF
							;;
							ListentDurationInMinutes)
								echo "Default_ListentDurationInMinutes:$BlockAttributeContent" >> $TMPCONF
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
									echo "${BlockName}_User:$BlockAttributeContent" >> $TMPCONF
								;;
								Mode)
									echo "${BlockName}_Mode:$BlockAttributeContent" >> $TMPCONF
								;;
								ListentDurationInMinutes)
									echo "${BlockName}_ListentDurationInMinutes:$BlockAttributeContent" >> $TMPCONF
								;;
								TCPPorts)
									echo "${BlockName}_TCPPorts:$BlockAttributeContent" >> $TMPCONF
								;;
								UDPPorts)
									echo "${BlockName}_UDPPorts:$BlockAttributeContent" >> $TMPCONF
								;;
							esac
							;;
							*)
								BlockAttributeContent=$(echo "${BlockContent}"|sed -n "/$BlockAttributeName/,/^[A-Za-z]/p"|grep -v ':'|tr '\n' ','|rev|cut -c2-|rev)
								case $BlockAttributeName in
									IPs)
										echo "${BlockName}_IPs:$BlockAttributeContent" >> $TMPCONF
									;;
									TestersIPs)
										echo "${BlockName}_TestersIPs:$BlockAttributeContent" >> $TMPCONF
									;;
									ListenersIPs)
										echo "${BlockName}_ListenersIPs:$BlockAttributeContent" >> $TMPCONF
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
#start Conf Validation
for BlockName in ${BlocksNames}
do
	if [ $BlockName != "Default" ]
	then 
		for Att in User Mode ListentDurationInMinutes
		do
			grep -q ${BlockName}_${Att} $TMPCONF 
			if [ $? -ne 0 ]
			then 
				grep -q Default_${Att} $TMPCONF
				if [ $? -eq 0 ]
				then
					echo "${BlockName}_${Att}:$(grep Default_${Att} $TMPCONF| cut -d':' -f2)" >> $TMPCONF
				elif [$? -ne 0 ]
				then
					echo "Invalid Configuration No $Att set in ${BlockName} and there is no default one" && exit 2
				fi
			fi
		done
		Mode=$(grep ${BlockName}_Mode $TMPCONF|cut -d':' -f2)
		case $Mode in
			bi)
				egrep -q "${BlockName}_TestersIPs|${BlockName}_ListenersIPs" $TMPCONF &&	echo "Block $BlockName has Mode $Mode can not have either TestersIPs or ListenersIPs in the conf file"  && exit 2
				grep -q "${BlockName}_IPs" $TMPCONF
				if [ $? -ne 0 ]
				then
					echo "Block $BlockName is in $Mode Mode with no IPs Attribute specified" &&	exit 2
				fi
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" $TMPCONF
				if [ $? -ne -0 ]
				then
					echo "$BlockName has no tcp or udp ports to test" &&	exit 2
				fi
			;;
			uni)
				grep -q "${BlockName}_IPs" $TMPCONF &&	echo Block $BlockName has Mode $Mode can not have IPs Attributes in the conf file && exit 2
				grep -q "${BlockName}_TestersIPs" $TMPCONF 
				if [ $? -ne 0 ]
				then 
					echo "Block $BlockName is in $Mode Mode with no TestersIps Attribute specified" && exit 2
				fi
				grep -q "${BlockName}_ListenersIPs" $TMPCONF
				if [ $? -ne 0 ]
				then 
					echo "Block $BlockName is in $Mode Mode with no ListenersIPs Attribute specified" && exit 2
				fi
				egrep -q  "${BlockName}_TCPPorts|${BlockName}_UDPPorts" $TMPCONF
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