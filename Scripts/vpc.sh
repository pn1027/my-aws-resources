#!/bin/bash

my_rand() {
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

public_subnets=()
private_subnets=()

echo "Enter CIDR (Press enter for default cidr 10.0.0.0/16): "
read cidr
if [ -z "$cidr" ];then 
    cidr=10.0.0.0/16
fi
echo "The cidr is : $cidr"

# Name should inlcude 4 parts, The name should be like —pallav-vpc-<date>-<random-number>

min=${1:-1}
max=${2:-1000}
vpc_name=$(my_rand 10 20)

# Create VPC
vpc_id=$(aws ec2 create-vpc\
 --cidr-block $cidr\
  --region $region\
   --query 'Vpc.VpcId'\
    --output text)
echo "VPC create with ID: $vpc_id"

#Adding name to the VPC
aws ec2 create-tags\
 --resources $vpc_id\
  --tags Key=Name,Value="$vpc_name"\
   --region $region\
    --output text
echo "VPC name is $vpc_name"
echo

            # create tags for vpc

            # echo "Enter Number of tags you want for VPC "
            # read num_tag
            # declare -a tags
            # for ((i=0; i<num_tag; i++)); do
            #     echo "Enter Key:"
            #     read key
            #     echo "Enter Value:"
            #     read value
            #     tags+=(Key=${key},Value=${value})
            # done

            aws ec2 create-tags --resources $vpc_id --tags Key="Date",Value="$(date +%D)" --region $region --output text


echo
subnet_index=1 #global counter to keep subnet numbering unique
#create subnets
subnet(){

    local subnet_type=$1
    subnet_type=$(echo "$subnet_type" | tr '[:upper:]' '[:lower:]')


    echo "Number of ${subnet_type} subnets want to create: "
    read num_subnet


for ((i=1;i<=num_subnet;i++)); do
    echo -n "Enter Cidr for $subnet_type $i (default 10.0.${subnet_index}.0/24): "
    read sub_cidr
    if [ -z "$sub_cidr" ]; then
        sub_cidr=10.0.${subnet_index}.0/24
    fi

        echo -n "Give availablity zone for subnet $i (eg: us-east-1a): "
        read az

        subnet_id=$(aws ec2 create-subnet \
                        --vpc-id $vpc_id\
                        --cidr-block $sub_cidr\
                        --availability-zone $az\
                        --region $region\
                        --query 'Subnet.SubnetId'\
                        --output text) 
        echo "Subnet created with id : $subnet_id"
        echo


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
            echo

        if [ "$subnet_type" == "public" ];then
            public_subnets+=("$subnet_id")
        else
        private_subnets+=("$subnet_id")
        fi

((subnet_index++))
done
}

auto_subnet(){
    echo "Creating Subnets automatically..."

    for i in {1..2}; do
    sub_cidr=10.0.${subnet_index}.0/24
    subnet_id=$(aws ec2 create-subnet\
                --vpc-id $vpc_id\
                --cidr-block $sub_cidr --availability-zone us-east-1a\
                --region $region
                --query 'Subnet.SubnetId'
                --output text)
    echo "Public subnet created with ID: $subnet_id"

   aws ec2 create-tags --resources $subnet_id --tags Key=Name,Value="Public$i" --region $region --output text

        public_subnets+=("$subnet_id")
        ((subnet_index++))
    done

    # Create 2 private subnets
    for i in {1..2}; do
        sub_cidr="10.0.${subnet_index}.0/24"
        subnet_id=$(aws ec2 create-subnet \
                        --vpc-id $vpc_id \
                        --cidr-block $sub_cidr \
                        --availability-zone us-east-1b \
                        --region $region \
                        --query 'Subnet.SubnetId' \
                        --output text)
        echo "Private Subnet $i created with id: $subnet_id"
        
        # Tagging private subnets with Private1, Private2
        aws ec2 create-tags --resources $subnet_id --tags Key=Name,Value="Private$i" --region $region --output text

        private_subnets+=("$subnet_id")
        ((subnet_index++))
    done
}





#calling the subnet function
echo
echo "Do you want to create Subnet? (yes/no): "
read sub
if [[ "$sub" =~ ^[Yy] ]]; then
    echo "Want to create Maunally or Automatically? (auto/manual): "
    read choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        
        case "$choice" in
        auto)
            auto_subnet
            ;;
        manual)
            echo "Select type (Public/Private/Both):"
            read type
            type=$(echo "$type" | tr '[:upper:]' '[:lower:]')

            case "$type" in
            public)
                subnet public
                ;;
            private)
                subnet private
                ;;
            both) 
                subnet public
                subnet private
                ;;
            *)
                echo "Invalid"
                ;;
            esac
            ;;
        *)
            echo "Invalid Choice"
            ;;
            esac
    fi


#Internet gateway for VPC
echo
igw_id=$(aws ec2 create-internet-gateway --region $region --query 'InternetGateway.InternetGatewayId' --output text)
echo "IGW id is $igw_id"
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region
echo


#Route table to make subnet public and private
if [ ${#public_subnets[@]} -gt 0 ]; then
public_route_table_id=$(aws ec2 create-route-table\
                            --vpc-id $vpc_id\
                            --region $region\
                            --query 'RouteTable.RouteTableId'\
                            --output text)
echo "Public route table id is $public_route_table_id"

aws ec2 create-route\
 --route-table-id $public_route_table_id\
   --destination-cidr-block 0.0.0.0/0\
    --gateway-id $igw_id\
    --region $region

 for subnet_id in "${public_subnets[@]}"; do
    aws ec2 associate-route-table --route-table-id $public_route_table_id --subnet-id $subnet_id --region $region
    done
fi 


if [ ${#private_subnets[@]} -gt 0 ]; then
    private_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --region $region --query 'RouteTable.RouteTableId' --output text)
    echo "Private route table Id: $private_route_table_id"

for subnet_id in "${private_subnets[@]}"; do
    aws ec2 associate-route-table --route-table-id $private_route_table_id --subnet-id $subnet_id
done
fi


# Security group name should be pallav-sg-04-13-2025-4576 
echo "Create security group for VPC"
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId, GroupName]' --output table

echo "Select one or press enter to create SG: "
read sg_id
if [ -z "$sg_id" ]; then
    sg_name=$(my_rand "$min" "$max")
    echo "The name of security group is $sg_name"

    sg_id=$(aws ec2 create-security-group --group-name $sg_name --description "My Security Group"\
     --vpc-id $vpc_id --query 'GroupId' --output text)
    echo "Security group created with id: $sg_id"

    aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id "$sg_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
fi

aws ec2 describe-vpcs --vpc-id $vpc_id --output text
}






#Function to show VPCs
show_vpc(){
    aws ec2 describe-vpcs --query Vpcs[*].VpcId --output table
}




# #Function to delete VPC
delete_vpc_resources() {
    
    local vpc_id=$1
    
    echo "Deleting resources for VPC: $vpc_id"
    echo
    
    # 1. Delete Security Groups
    echo "Deleting security groups..."
    for sg in $(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$vpc_id" \
              "Name=group-name,Values=*" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text); do
    aws ec2 delete-security-group --group-id "$sg"
    echo "Deleted security group: $sg"
    done
    
    # 2. Delete Route Table Associations and Routes
    echo
    echo "Deleting route tables..."
    for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=false" --query 'RouteTables[*].RouteTableId' --output text); do
        # Delete route table associations
        for assoc in $(aws ec2 describe-route-tables --route-table-id "$rt" --query 'RouteTables[*].Associations[*].RouteTableAssociationId' --output text); do
            aws ec2 disassociate-route-table --association-id "$assoc"
        done
        # Delete route table if it's not the main one
            aws ec2 delete-route-table --route-table-id "$rt"
            echo "Deleted Route Table: $rt"
        
    done
    
    # 3. Delete Internet Gateway
    echo
    echo "Deleting internet gateway..."
    for igw in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text); do
        aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw"
        echo "Deleted internet gateway: $igw"
    done
    
    # 4. Delete Subnets
    echo
    echo "Deleting subnets..."
    for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text); do
        aws ec2 delete-subnet --subnet-id "$subnet"
        echo "Deleted subnet: $subnet"
    done
    
    # 5. Finally Delete VPC
    echo
    echo "Deleting VPC..."
    aws ec2 delete-vpc --vpc-id "$vpc_id"
    echo "Successfully deleted VPC and all associated resources"
}
