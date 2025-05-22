#!/bin/bash

echo "Give name to user: "
read user
aws iam create-user --user-name $user

echo "Password you want to create: "
read Password
aws iam create-login-profile --user-name $user --password $Password


echo
echo "Creating Access Key"
aws iam create-access-key --user-name $user\
 --query 'AccessKey.{AccessKeyID:AccessKeyId,SecretAccessKey:SecretAccessKey}'\
 --output json

echo "NOTE THE KEYS, WON'T BE SHOWN AGAIN"

echo
echo "Choose Policy" 
echo "1. AWS managed policy"
echo "2. Custom Policy"
echo "3. Default S3 Full Access policy"
read -rp "Enter 1,2 or 3: " choice

case "$choice" in
    1) 
    echo
    echo "Listing AWS Managed policies"
    aws iam list-policies --scope AWS --max-items 6 --query 'Policies[*].{Name:PolicyName,ARN:Arn}' --output json
    read -rp "Enter ARN" policy 
    ;;
    2)
    echo
    echo "Listing Custom Managed policies"
    aws iam list-policies --scope Local --max-items 10 --query 'Policies[*].{Name:PolicyName,ARN:Arn}' --output json
    read -rp "Enter ARN" policy 
    ;;
    3)
    echo
    policy="arn:aws:iam::aws:policy/AmazonS3FullAccess"
    ;;
esac

aws iam attach-user-policy --user-name $user --policy-arn $policy

read -rp "Enter Role name: " ROLE_NAME
echo "Creating role: $ROLE_NAME"
USER_ARN=$(aws iam get-user --user-name "$user" --query 'User.Arn' --output text)
TRUST_POLICY="trust-${ROLE_NAME}.json"
cat > "${TRUST_POLICY}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "$USER_ARN" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role \
      --role-name "$ROLE_NAME" \
      --assume-role-policy-document file://${TRUST_POLICY}

aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess


rm -f "${TRUST_POLICY}"


Account=$(aws sts get-caller-identity --query "Account" --output text)
Signin="https://$Account.signin.aws.amazon.com/console"
echo
echo "Url to Sign in $Signin"