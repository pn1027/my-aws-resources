#!/bin/bash

#Name and Tags 


#Instance Type 
    #  Number of CPUs 
    #  Memory (GB) 
    #  Storage (GB) 
    #  Network Performance
echo "List of Instances Types"
echo
aws ec2 describe-instance-types\
 --filters Name=current-generation,Values=true\
  --query "InstanceTypes[*].InstanceType"\
   --output text | tr '\t' '\n' | grep 'micro'
read InstanceType
echo "The Instance Type selected is $InstanceType"


#AMI

#Key Pair (Select or Create new)
    #  Name
    #  Type(RSA,ED25519)
    #  file format (.pem or .ppk)
echo "Create Key Pair"
echo "Key pair Name"
read name
echo "Enter Type (rsa/ED25519): "
read type
echo "Key Pair Format (pem or ppk)"
read format

if [ "$format" == "pem" ]; then
aws ec2 create-key-pair --key-name $name\
                        --key-type $type\
                        --key-format $format\
                        --query 'KeyMaterial'\
                        --output text > "${name}.pem" #To save file >
    
    chmod 400 "${name}.pem"
    echo "Key pair saved as ${name}.pem"

else     
    aws ec2 create-key-pair --key-name $name\
                            --key-type $type\
                            --key-format $format\
                            --query 'KeyMaterial'\
                            --output text
    echo "(Key Material displayed above)"
fi

KeyPairID=$(aws ec2 describe-key-pairs --key-names "$name" --query 'KeyPairs[0].KeyPairId' --output text)




#Network Setting 
    # Select VPC
    aws ec2 describe-vpcs --query 'Vpcs[*].{Id: VpcId, Name: Tags[?Key==`Name`] | [0].Value}'  --output table
    echo "Enter VPC ID: "
    read vpc_id
    echo
    echo "This is the selected $vpc_id"
    echo 
    # Select subnet
    echo "Which subnet you want to create the EC2? (Public or Private):"
    # Auto-assign public IP
    # assign Security Group


# aws ec2 describe-vpcs 

# read subnet_type


subnet_id=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$vpc_id --query Subnets[*].SubnetId --output table)
echo "$subnet_id"
