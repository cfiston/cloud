#curl -sSL https://gist.github.com/abajwa-hw/9d7d06b8d0abf705ae311393d2ecdeec/raw | sudo -E sh

export vm_name=${vm_name:-demo} 
export domain_name=${domain_name:-hortonworks.com}
export cm_mode=${cm_mode:-false}

echo "# Do not remove the following line, or various programs" > /etc/hosts
echo "# that require network functionality will fail." >> /etc/hosts
echo "127.0.0.1  localhost  localhost.localdomain" >> /etc/hosts

function get_inet_iface(){
	route | grep default | awk '{print $8}'
}


function get_ip() {
	#ip addr | grep 'inet ' | grep -v -E "( lo| $(get_inet_iface))" | awk '{ print $2 }' | awk -F'/' '{print $1}'
	ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'
}

function get_ip_power() {
 ip addr | grep 'eth0' | tail -n1 | awk '{print $2}' | cut -f1  -d'/'
} 

HOST=$(get_ip)
NUM=5
while [ -z "$HOST" ]; do
	HOST=$(get_ip)
        if [ -z "$HOST" ]; then
	   HOST=$(get_ip_power)
	fi
	sleep 5
	NUM=$(($NUM-1))
	if [ $NUM -le 0 ]; then
		HOST="127.0.0.1"
		echo "Failed to update IP"
		break
	fi
done
if [ "${cm_mode}" = true  ]; then
  echo "${HOST} ${vm_name}.${domain_name} ${vm_name} # $(hostname -f) $(hostname -s)" >> /etc/hosts
else
  echo "${HOST} ${vm_name}.${domain_name} ${vm_name} $(hostname -f) $(hostname -s)" >> /etc/hosts
fi

#On centos 7, use hostnamectl to change name permanently
hostnamectl
if [ $? = 0 ]; then
    hostnamectl set-hostname ${vm_name}.${domain_name}
    hostnamectl --transient set-hostname ${vm_name}    
fi
hostname ${vm_name}.${domain_name}
echo 0 > /proc/sys/kernel/hung_task_timeout_secs
ethtool -K eth0 tso off
#ethtool -K eth1 tso off