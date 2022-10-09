# This is an example
# I would run this locally on my laptop, _not_ on the remote server
#
KEY=../keys/jwm_tmp_hacking_us-east-1.pem
SSH_SERVER="ec2-changeme.compute-1.amazonaws.com"

# Example where:
#  minikube ip is returning 192.168.49.2 on the remote minikube instance
#  I want to access the remote minikube service locally on port 7080

ssh -L 7080:192.168.49.2:80 -i ${KEY} centos@${SSH_SERVER}

#ssh -L [LOCAL_IP:]LOCAL_PORT:DESTINATION:DESTINATION_PORT [USER@]SSH_SERVER
