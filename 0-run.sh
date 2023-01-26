#!/bin/bash

# This script assumes you have the aws cli installed, in your path and configured
# Assumes jq is installed
# Assumes a clean AWS account for the most part
# If you're not running this for the first time, clean out the following
# [] headscale ec2 instnace
# [] headscale security group
# [] headscale route53 A record (part of the sandbox.opentlc.com hosted zone)
# [] default vpc

# TODO
# [] IP elastic IP being assigned changes on ec2 instance reboot, not ideal for A record


# include vars from config file
. ./config.sh

# create the keypair if doesn't already exist
aws ec2 describe-key-pairs --key-name rh-headscale
EC=$?
if [ $EC -ne 0 ]; then
  echo "rh-headscale keypair doesn't exist, creating it..."
  aws ec2 create-key-pair --key-name rh-headscale --query KeyMaterial --output text > rh-headscale.pem
  sudo chmod 600 rh-headscale.pem 
  echo "export AWS_KEYPAIR=rh-headscale" >> ~/.bashrc
  source ~/.bashrc
  echo $AWS_KEYPAIR
  aws ec2 describe-key-pairs --key-name rh-headscale | jq "."
fi            


# Get your local IP for SG rules
MY_IP=$(curl https://checkip.amazonaws.com)

# create a default vpc
VPC_ID=$(aws ec2 create-default-vpc | jq -r ".Vpc.VpcId")
echo "New Default_VPC_ID: ${VPC_ID}"

# create security group
SG_ID=$(aws ec2 create-security-group --group-name headscale --description "Headscale node security group" --vpc-id ${VPC_ID} | jq -r ".GroupId")
echo "Headscale SG ID: ${SG_ID}"

# open required port(s)
aws ec2 authorize-security-group-ingress --group-name headscale --protocol tcp --port 22 --cidr ${MY_IP}/32
aws ec2 authorize-security-group-ingress --group-name headscale --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name headscale --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 describe-security-groups --group-ids ${SG_ID} | jq "."

# grab the first subnet of the new vpc
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" | jq -r ".Subnets[0].SubnetId")
echo "SUBNET_ID: ${SUBNET_ID}"

# create the headscale ec2 instance on RHEL9
INSTANCE_INFO=$(aws ec2 run-instances \
  --image-id ${RHEL9_AMI} \
  --count 1 \
  --instance-type t2.micro \
  --key-name rh-headscale \
  --security-group-ids ${SG_ID} \
  --subnet-id ${SUBNET_ID} \
  --associate-public-ip-address \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{\"VolumeSize\":40,\"DeleteOnTermination\":true}}]" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=headscale}]' 'ResourceType=volume,Tags=[{Key=Name,Value=headscale-server-disk}]' \
  --user-data file://user-data.sh \
  --query 'Instances[0]')

echo "INSTANCE_INFO: ${INSTANCE_INFO}"
INSTANCE_ID=$(echo $INSTANCE_INFO | jq -r '.InstanceId')

echo "INSTANCE_ID: ${INSTANCE_ID}"
sleep 10 #time for instance to get IP

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text)
echo "PUBLIC_IP: ${PUBLIC_IP}"

# get the opentlc hosted zone 
DOMAIN=$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name | test("^[^.]*.opentlc.com.$")) |.Name')
ZONE_ID=$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name | test("^[^.]*.opentlc.com.$")) |.Id')
echo "DOMAIN: ${DOMAIN}"
echo "ZONE_ID: ${ZONE_ID}"

echo "Create headscale.${DOMAIN}..."
aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch '{"Comment": "Creating A record for headscale subdomain", "Changes": [{"Action": "CREATE", "ResourceRecordSet": {"Name": "headscale.'$DOMAIN'", "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": "'"$PUBLIC_IP"'"}]}}]}'

echo "Connect to the headscale instance:"
echo "ssh -i rh-headscale.pem ec2-user@${PUBLIC_IP}"