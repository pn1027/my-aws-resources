#!/bin/bash

create_ec2() {
    # Name and Tags
    echo
    echo "Enter a Name tag for your EC2 instance:"
    read instance_name
    echo

    # Instance Type 
    echo "List of Instance Types"
    echo
    aws ec2 describe-instance-types\
        --filters Name=current-generation,Values=true\
        --query "InstanceTypes[*].InstanceType"\
        --output text | tr '\t' '\n' | grep 'micro'
    echo
    echo "Enter the instance type you want to use:"
    read InstanceType
    echo "The Instance Type selected is $InstanceType"

    # AMI
    echo
    aws ec2 describe-images --owners amazon --filter "Name=name,Values=al2023-ami-2023.*" --query 'Images[*].[CreationDate,ImageId,Name]' --output table
    echo "Write AMI or press enter to use the default ami"
    read ami
    if [ -z "$ami" ]; then
        ami="ami-0e449927258d45bc4"
    fi

    echo "Using ami: $ami"

    # Key Pair (Select or Create new)
    echo
    aws ec2 describe-key-pairs --query KeyPairs[*].[KeyPairId,KeyName] --output table
    echo "Select or Press Enter to Create Key Pair"
    read Keypair

    if [ -z "$Keypair" ]; then
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
                                    --output text > "${name}.pem" # To save file
            
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
    else
        KeyPairID=$(aws ec2 describe-key-pairs --key-names "$Keypair" --query 'KeyPairs[0].KeyPairId' --output text)
    fi

    echo "The KeyPair ID is: $KeyPairID"

    # Network Settings
    aws ec2 describe-vpcs --query 'Vpcs[*].{Id: VpcId, Name: Tags[?Key==`Name`] | [0].Value}'  --output table
    echo "Enter VPC ID: "
    read vpc_id
    echo
    echo "This is the selected $vpc_id"
    echo

    # Select subnet
    echo "Which subnet you want to create the EC2? (Public or Private):"
    read subnet_type
    subnet_type_lower=$(echo "$subnet_type" | tr '[:upper:]' '[:lower:]')

    echo "Finding route tables for VPC: $vpc_id"
   route_tables=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id --query 'RouteTables[*].RouteTableId' --output text)

# Check each Route Table for Internet Gateway
for rt_id in $route_tables; do
    # Check if the route table has an internet gateway
    has_igw=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Routes[?starts_with(GatewayId, `igw-`)].GatewayId' --output text)

    # If IGW exists (Public route table)
    if [ "$subnet_type_lower" == "public" ] && [ -n "$has_igw" ]; then
        aws ec2 describe-route-tables --route-table-ids $rt_id \
            --query 'RouteTables[].Associations[].SubnetId' --output text
    fi

    # If NO IGW (Private route table)
    if [ "$subnet_type_lower" == "private" ] && [ -z "$has_igw" ]; then
        aws ec2 describe-route-tables --route-table-ids $rt_id \
            --query 'RouteTables[].Associations[].SubnetId' --output text
    fi
done

    echo
    echo "Enter Subnet ID to use:"
    read subnet_id_selected
    echo "Selected Subnet: $subnet_id_selected"

    # Assign Security Group
    echo
    echo "Security Groups for VPC: $vpc_id"
    echo
    aws ec2 describe-security-groups \
        --filters Name=vpc-id,Values=$vpc_id \
        --query 'SecurityGroups[*].[GroupId, GroupName]' \
        --output table

    echo
    echo "Enter Security Group ID to use:"
    read sg
    echo "Selected Security Group: $sg"

    echo
    echo "Launching EC2 instance..."

    instance_id=$(aws ec2 run-instances \
        --image-id "$ami" \
        --instance-type "$InstanceType" \
        --key-name "$(aws ec2 describe-key-pairs --key-pair-ids "$KeyPairID" --query 'KeyPairs[0].KeyName' --output text)" \
        --subnet-id "$subnet_id_selected" \
        --security-group-ids "$sg" \
        --associate-public-ip-address \
        --count 1 \
        --query 'Instances[0].InstanceId' \
        --output text)

    aws ec2 create-tags \
        --resources "$instance_id" \
        --tags Key=Name,Value="$instance_name"

    echo
    echo "Instance launched successfully! Instance ID: $instance_id"
}

ec2_delete() {
    echo "Listing available EC2 instances..."
    aws ec2 describe-instances \
        --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value | [0]]" \
        --output table

    # Prompt for EC2 Instance ID
    echo "Enter the EC2 Instance ID to delete: "
    read instance_id

    # Terminate the EC2 instance
    echo "Terminating EC2 instance $instance_id..."
    aws ec2 terminate-instances --instance-ids "$instance_id" --output text
    echo "Termination requested for instance $instance_id."

    # Wait for the instance to terminate
    echo "Waiting for instance termination..."
    aws ec2 wait instance-terminated --instance-ids "$instance_id"
    echo "EC2 instance $instance_id terminated successfully."

    # Delete the KeyPair
    echo "Enter Key Pair name to delete: "
    read Keypair
    aws ec2 delete-key-pair --key-name "$Keypair"
    echo "Key pair $Keypair deleted."
}
