#! /bin/bash
function find_replace_oracle_ip() {
  #grep $ORACLE_HOME/tnsnames.ora -e '<your-oracle-private-ip>'
  echo "find and replace oracle ip ... $1"
  grep $1 -e '<your-oracle-private-ip>'
  if [ $? == 0 ]; then
    echo "finding oracle ec2 private ip ...."
    PRIVATE_IP_ADDR=`aws ec2 describe-instances --region=ap-northeast-2 \
    --filters "Name=tag:Name,Values=tf_oracle_11xe" \
    --query "Reservations[*].Instances[*].{PrivateIpAddress:PrivateIpAddress}" \
    --output=text`

    sed -i "s/<your-oracle-private-ip>/$PRIVATE_IP_ADDR/g" $1
  fi
}

find_replace_oracle_ip $ORACLE_HOME/tnsnames.ora
find_replace_oracle_ip /home/ec2-user/pyoracle/config.ini

sqlplus system/manager@xe @oracle-schema.sql
