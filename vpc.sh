#!/bin/bash


my-rand() {
local min=${1:-1}
local max=${2:-1000}

local range=$((max - min + 1))
local rand=$((RANDOM % range + min))

local hash=$(echo -n "$rand" | sha256sum | awk '{print substr($1, 1, 4)}')
local date_str=$(date +"%Y%m%d")

echo "pallav-$1-${hash}-${date_str}"
}

create_vpc() {
region=$(aws configure get region)
echo "The region is $region"

echo "Enter CIDR: "
read cidr

if [ -z "$cidr" ];then 
    cidr=10.0.0.0/16
fi

echo "The cidr is : $cidr"

# Name should inlcude 4 parts, The name should be like —pallav-vpc-<date>-<random-number>

min=${1:-1}
max=${2:-1000}

vpc_name=$(my-rand "$1" "$2")

# Create VPC
vpc_id=$(aws ec2 create-vpc --cidr-block $cidr --region $region --query 'Vpc.VpcId' --output text)
echo "VPC create with ID: $vpc_id"

#Adding name to the VPC
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value="$vpc_name" --region $region --output text
echo "VPC name is $vpc_name"


# create tags for vpc
echo "enter number tags you want for VPC "
read num_tag

declare -a tags
for ((i=0; i<num_tag; i++)); do
    echo "Enter Key:"
    read key
    echo "Enter Value:"
    read value
    tags+=(Key=${key},Value=${value})
done
aws ec2 create-tags --resources $vpc_id --tags "${tags[@]}" --region $region --output text


#create subnet
echo "Number of subnets want to create (both public and private): "
read num_subnet

declare -a public_subnets private_subnets
for ((i=1;i<=num_subnet;i++)); do
    echo -n "Enter Cidr for subnet $i(default 10.0.$i.0/24): "
    read sub_cidr
    if [ -z "$sub_cidr" ]; then
        sub_cidr=10.0.$i.0/24
    fi

echo "should subnet be public or private?"
read subnet_type
subnet_type=$(echo "$subnet_type" | tr '[:upper:]' '[:lower:]')


echo -n "Give availablity zone for subnet $i: (eg: us-east-1a) "
read az

subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $sub_cidr --availability-zone $az --region $region --query 'Subnet.SubnetId' --output text) 
echo "Subnet created with id : $subnet_id"

#Adding tags to subnet
echo "Number of tags for subnet: "
read num_tag_subnet

declare -a tags_subnet
for ((j=0;j<num_tag_subnet;j++)); do
echo "Enter Key: "
read key
echo "Enter Value: "
read value
tags_subnet+=(Key=${key},Value=${value})
done
aws ec2 create-tags --resources $subnet_id --tags "${tags_subnet[@]}" --region $region --output text


if [ "$subnet_type" == "public" ];then
    public_subnets+=("$subnet_id")
else
private_subnets+=("$subnet_id")
fi
done


#Internet gateway for VPC
igw_id=$(aws ec2 create-internet-gateway --region $region --query 'InternetGateway.InternetGatewayId' --output text)
echo "IGW id is $igw_id"
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region

#Route table to make subnet public and private
if [ ${#public_subnets[@]} -gt 0 ]; then
public_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --query 'RouteTable.RouteTableId' --output text)
echo "Public route table id is $public_route_table_id"

aws ec2 create-route --route-table-id $public_route_table_id  --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id

 for subnet_id in "${public_subnets[@]}"; do
    aws ec2 associate-route-table --route-table-id $public_route_table_id --subnet-id $subnet_id
    done
fi 

for subnet_id in "${private_subnets[@]}"; do
    private_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --query 'RouteTable.RouteTableId' --output text)
    echo "Private route table id is $private_route_table_id"

    aws ec2 associate-route-table --route-table-id $private_route_table_id --subnet-id $subnet_id
done

# Security group name should be pallav-sg-04-13-2025-4576 
echo "Create security group for VPC"
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId, GroupName]' --output table

echo "Select one or press enter to create SG: "
read sg_id
if [ -z "$sg_id" ]; then
    sg_name=$(my-rand "$min" "$max")
    echo "The name of security group is $sg_name"

    sg_id=$(aws ec2 create-security-group --group-name $sg_name --description "My Security Group"\
     --vpc-id $vpc_id --query 'GroupId' --output text)
    echo "Security group created with id: $sg_id"

    aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
fi
}





#Function to show VPCs
show_vpc(){
    aws ec2 describe-vpcs --query Vpcs[*].VpcId --output table
}




# #Function to delete VPC
delete_vpc_resources() {
    local vpc_id=$1
    
    echo "Deleting resources for VPC: $vpc_id"
    
    # 1. Delete Security Groups
    echo "Deleting security groups..."
    for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[*].GroupId' --output text); do
        aws ec2 delete-security-group --group-id "$sg"
        echo "Deleted security group: $sg"
    done
    
    # 2. Delete Route Table Associations and Routes
    echo "Deleting route tables..."
    for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[*].RouteTableId' --output text); do
        # Delete route table associations
        for assoc in $(aws ec2 describe-route-tables --route-table-id "$rt" --query 'RouteTables[*].Associations[*].RouteTableAssociationId' --output text); do
            aws ec2 disassociate-route-table --association-id "$assoc"
        done
        # Delete route table if it's not the main one
        if ! aws ec2 describe-route-tables --route-table-id "$rt" --query 'RouteTables[*].Associations[*].Main' --output text | grep -q "True"; then
            aws ec2 delete-route-table --route-table-id "$rt"
        fi
    done
    
    # 3. Delete Internet Gateway
    echo "Deleting internet gateway..."
    for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text); do
        aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw"
        echo "Deleted internet gateway: $igw"
    done
    
    # 4. Delete Subnets
    echo "Deleting subnets..."
    for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text); do
        aws ec2 delete-subnet --subnet-id "$subnet"
        echo "Deleted subnet: $subnet"
    done
    
    # 5. Finally Delete VPC
    echo "Deleting VPC..."
    aws ec2 delete-vpc --vpc-id "$vpc_id"
    echo "Successfully deleted VPC and all associated resources"
}




# Dispatcher to call functions by name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ -z "$1" ]]; then
    echo "Choose an option:"
    echo "1) Create VPC"
    echo "2) Show VPCs"
    echo "3) Delete VPC"
    read -rp "Enter choice [1-3]: " choice

    case $choice in
      1)
        echo -n "Enter min value for random number (default 1): "
        read min
        echo -n "Enter max value for random number (default 1000): "
        read max
        create_vpc "${min:-1}" "${max:-1000}"
        ;;
      2)
        show_vpc
        ;;
      3)
        echo -n "Enter VPC ID to delete: "
        read vpc_id
        delete_vpc_resources "$vpc_id"
        ;;
      *)
        echo "Invalid choice."
        exit 1
        ;;
    esac
  else
    if declare -f "$1" > /dev/null; then
      func="$1"
      shift
      "$func" "$@"
    else
      echo "Function '$1' not found in $0"
      exit 1
    fi
  fi
fi

 