#!/bin/sh

if [ $# -lt 2 ]; then
  echo "give HOST(~/.ssh/config), group-name [, profile(~/.aws/config)] as arguments"  1>&2
  echo "$ ssh_ec2 Hostname group-name default" 1>&2
  exit 1
fi

HOST=$1
GROUP_NAME=$2
PROFILE="default"
if [ $# -gt 2 ]; then
  PROFILE=$3
  echo "use aws profile $PROFILE" 1>&2
fi
MY_WAN_IP=$(curl --max-time 2 -s http://whatismyip.akamai.com/)

echo "adding WAN-IP to security-group-ingress" 1>&2


# NOTE: convert group-name to group-id
GROUP_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values"=$GROUP_NAME" | jq -r '.SecurityGroups[].GroupId')

echo "security group-id=$GROUP_ID"

# NOTE: should use group-id instead of group-name with --profile(https://github.com/aws/aws-cli/issues/1207)
AUTHORIZE_CMD="aws ec2 authorize-security-group-ingress --profile $PROFILE --group-id $GROUP_ID --protocol tcp --port 22 --cidr $MY_WAN_IP/32"

echo "try command: $AUTHORIZE_CMD"

$AUTHORIZE_CMD

ret_auth=$?

if [ $ret_auth -ne 0 ]; then
  echo "host in ~/.aws/config is configured and correct?"
  echo "---------------~/.aws/config--------------------"
  echo "[default]"
  echo "aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxx"
  echo "aws_access_key_id = XXXXXXXXXXXXXXXXXXXXXXXX"
  echo "region = ap-northeast-1"
  echo "output = json"
  if [ $# -gt 4 ]; then
    echo ""
    echo "[profile $PROFILE]"
    echo "aws_secret_access_key = xxxxxxxxxxxxxxxxx"
    echo "aws_access_key_id = XXXXXXXXXXXXXXXXXXXXXXXX"
    echo "region = us-west-2"
    echo "output = json"
  fi
  echo "------------------------------------------------"
fi


echo "try ssh..."  1>&2

SSH_CMD="ssh $HOST"
echo "$SSH_CMD"
$SSH_CMD

ret_ssh=$?

if [ $ret_ssh -ne 0 ]; then
  echo "host in ~/.ssh/config is configured and correct?"
  echo "-------------~/.ssh/config--------------"
  echo "Host $HOST"
  echo "  Hostname <IP or HOSTNAME>"
  echo "  User <LOGIN_USER>"
  echo "  IdentityFile ~/.ssh/<SSH_SECRET_KEY>"
  echo "----------------------------------------"
fi

echo "revoke WAN-IP from security-group-ingress"  1>&2

REVOKE_CMD="aws ec2 revoke-security-group-ingress --profile $PROFILE --group-id $GROUP_ID --protocol tcp --port 22 --cidr $MY_WAN_IP/32"
echo "$REVOKE_CMD"
$REVOKE_CMD
