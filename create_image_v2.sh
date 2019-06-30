#curl -sSL https://gist.github.com/abajwa-hw/408134e032c05d5ff7e592cd0770d702/raw | sudo -E sh

#################################
## write out start_services.sh  #
#################################

cat > /root/start_services.sh <<-'EOS'

export ambari_user=demokitadmin
export ambari_pass=BadPass#1
export log="/var/log/hdp_startup.log"

#detect name of cluster
output=`curl -s -u ${ambari_user}:${ambari_pass} -i -H 'X-Requested-By: ambari'  http://localhost:8080/api/v1/clusters`
cluster_name=`echo $output | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p'`

echo "Starting cluster ${cluster_name}..." >> ${log}

#form start_cmd
read -r -d '' start_cmd <<EOF
curl -u ${ambari_user}:${ambari_pass} -i -H "X-Requested-By: blah" -X PUT -d  '{"RequestInfo":{"context":"_PARSE_.START.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"'"${cluster_name}"'"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}' http://localhost:8080/api/v1/clusters/${cluster_name}/services
EOF

#run command and get request id
echo "Requesting Ambari to start all.." >> ${log}
req_output=$(eval ${start_cmd})
req=$(echo ${req_output} | sed -n 's/.*"id" : \([0-9]*\),.*/\1/p')

#check status of request using its id
read -r -d '' status_cmd <<EOF
curl -u ${ambari_user}:${ambari_pass} -i -H "X-Requested-By: blah" -X GET http://localhost:8080/api/v1/clusters/${cluster_name}/requests/${req} | sed -n 's/.*"request_status" : "\([^\"]*\)".*/\1/p'
EOF
status=$(eval $status_cmd)
echo "status of request ${req} is ${status}"

#wait until request processing completed
until ([ "$status" != "IN_PROGRESS" ] && [ "$status" != "PENDING" ]);
do
 echo "Waiting for start all operation to complete..." >> ${log}
 sleep 5
 status=$(eval $status_cmd)
done

#check last status: if request failed, retry once
if [ "${status}" == "FAILED" ]; then
  echo "Start all failed. Retrying operation once more..." >> ${log}
  sleep 5
  eval ${start_cmd} >> ${log}
elif [ "${status}" == "COMPLETED" ]; then
   echo "Start all operation completed. Cluster is ready" >> ${log}
else
   echo "Operation did not succeed. Status was ${status}" >> ${log}
fi

EOS
chmod +x  /root/start_services.sh






#####################
#append to rc.local #
#####################

cat <<'EOS' >> /etc/rc.local

echo "Sleeping for 30s..." > /var/log/hdp_startup.log
sleep 30

echo "generating new /etc/hosts that includes demo.keibacloud.com entry pointing to VMs ip, hostname..."  >> /var/log/hdp_startup.log
curl -sSL https://gist.github.com/abajwa-hw/9d7d06b8d0abf705ae311393d2ecdeec/raw | sudo -E sh >> /var/log/hdp_startup.log
echo "hostname is $(hostname -f)" >> /var/log/hdp_startup.log
echo "hostnamectl output is $(hostnamectl)" >> /var/log/hdp_startup.log

echo "starting Ambari..."  >> /var/log/hdp_startup.log
service ambari-server restart
service ambari-agent restart

ambari_up=0
until [ "$ambari_up" -eq "1" ];
do
 echo "Waiting for Ambari to bind to port..." >> /var/log/hdp_startup.log
 sleep 5
 ambari_up=$(netstat -tulpn | grep 8080 | wc -l)
done

echo "Waiting 15s..." >> /var/log/hdp_startup.log
sleep 15

USER=demokitadmin
PASSWORD=BadPass#1
AMBARI_HOST=localhost
HOST=$(hostname -f)

#detect name of cluster
output=`curl -s -u ${USER}:${PASSWORD} -i -H 'X-Requested-By: ambari'  http://localhost:8080/api/v1/clusters`
cluster_name=`echo $output | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p'`


#sleep until agent comes up
until [ $(curl -u ${USER}:${PASSWORD} -H  X-Requested-By:blah http://{$AMBARI_HOST}:8080/api/v1/hosts/${HOST} | grep '"host_status"\s\+:\s\+"UNHEALTHY"' | wc -l) -eq "1" ];
do
 echo "Cluster in unknown state...Sleeping for 10s while waiting for Ambari" >> /var/log/hdp_startup.log
 sleep 10
done


status=$(curl -u ${USER}:${PASSWORD} -H  X-Requested-By:blah http://{$AMBARI_HOST}:8080/api/v1/hosts/${HOST} | grep '"host_status"')
echo "Cluster Status: ${status}"  >> /var/log/hdp_startup.log

echo "Requesting Ambari to start up HDP services..."  >> /var/log/hdp_startup.log
/root/start_services.sh >> /var/log/hdp_startup.log

echo "Startup script complete." >> /var/log/hdp_startup.log
echo "Login to Ambari at http://$(curl icanhazip.com):8080 using username=admin and password=<Your AWS account number>" >> /var/log/hdp_startup.log
EOS

chmod a+x /etc/rc.local
