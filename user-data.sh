#!/bin/bash


# Ref: deploying headscale containerized
# https://github.com/juanfont/headscale/blob/main/docs/running-headscale-container.md

DELIM="::-----> "

main_function() {
  echo "${DELIM}starting headscale server install..."
  echo "${DELIM}installing required packages..."
  dnf install wget podman vim bind-utils firewalld -y
  
  echo "${DELIM}setting firewalld rules..."
  systemctl enable --now firewalld
  firewall-cmd --zone public --permanent --add-service=http
  firewall-cmd --zone public --permanent --add-service=https
  firewall-cmd --zone public --permanent --add-port=8080/tcp #verify this
  firewall-cmd --reload

  echo "${DELIM}adjust priv port range down for podman rootless..."
  sysctl net.ipv4.ip_unprivileged_port_start=443
  sysctl -w net.ipv6.conf.all.forwarding=1
  sysctl -w net.ipv4.ip_forward=1
  echo "net.ipv4.ip_unprivileged_port_start=443" > /etc/sysctl.d/local.conf
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/local.conf
  echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/local.conf

  echo "${DELIM}prep headscale directory structure..."
  mkdir -p /opt/headscale/config
  touch /opt/headscale/config/db.sqlite
  # todo change ownership of /opt/headscale to ec2-user

  echo "${DELIM}injecting config.yaml for headscale..."
  # todo

  echo "::starting headscale container..."
  # todo, run this as a user with su -c 
  #podman run -d --name headscale -v /opt/headscale/config:/etc/headscale:Z \
  #  -p 8080:8080 \
  #  -p 9090:9090 \
  #  docker.io/headscale/headscale:latest \
  #  headscale serve
  

}


main_function > >(tee -a "/var/log/bootstrap.log") 2>&1

if [ $? -eq 0 ]
then
    echo 'Bootstrap Success!' >> /var/log/bootstrap.log
else
    echo 'Bootstrap Failure!' >> /var/log/bootstrap.log
fi