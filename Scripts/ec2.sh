#!/bin/bash

user_data_option=""
create_ec2() {

    echo "Enter 1 to create instance by launch template or 2 for Manual"
    read choice 
    case "$choice" in
    1)
    echo "Available Launch Templates:"
    aws ec2 describe-launch-templates --query 'LaunchTemplates[*].{Id: LaunchTemplateId,Name: LaunchTemplateName}' --output json
    echo "Enter Launch template ID"
    read id

    aws ec2 run-instances\
    --launch-template LaunchTemplateId=$id,Version=1
    ;;
    2)
    aws ec2 describe-vpcs --query 'Vpcs[*].{Id: VpcId, Name: Tags[?Key==`Name`] | [0].Value}'  --output table
    echo "Enter VPC ID: "
    read vpc_id
    echo
    echo "This is the selected $vpc_id"
    echo

    # Name and Tags
    echo
    echo "Enter a Name tag for your EC2 instance:"
    read instance_name
    echo

    # Instance Type 
    echo "List of Instance Types: "
   
    aws ec2 describe-instance-types\
        --filters Name=current-generation,Values=true\
        --query "InstanceTypes[*].InstanceType"\
        --output text | tr '\t' '\n' | grep 'micro' | head -n 4
    echo
    echo "Enter the instance type you want to use:"
    read InstanceType
    echo "The Instance Type selected is $InstanceType"

    # AMI
    echo
    aws ec2 describe-images --owners amazon --filter "Name=name,Values=al2023-ami-2023.*" --query 'Images[*].[CreationDate,ImageId,Name]' --output table | sort -r | head -n 10
    echo
    echo "Write AMI OR press ENTER to use the default ami"
    read ami
#####################################################################################################################
    if [ -z "$ami" ]; then
        echo "Retriving AMI from Parameter store"
        retrieved_ami=`MSYS_NO_PATHCONV=1 aws ssm get-parameter --name /pallav/ec2/ami --query 'Parameter.Value' --output text`

        if [[ $retrieved_ami == ami-* ]]; then
            ami="$retrieved_ami"
            echo "Retrived AMI from SSM: $ami"
        else
            ami="ami-0e449927258d45bc4"
            echo "Using default hardcoded ami: $ami"
        fi
    fi

   echo
   echo "Storing AMI ID in Parameter store..."
   MSYS_NO_PATHCONV=1 aws ssm put-parameter --name '/pallav/ec2/ami' --type String --value $ami --overwrite

######################################################################################################################

    # Key Pair (Select or Create new)
    echo
    aws ec2 describe-key-pairs --query KeyPairs[*].[KeyPairId,KeyName] --output table
    echo "Type Name of KeyPair or Press Enter to Create Key Pair"
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
    # Select subnet
    echo
    echo "Which subnet you want to create the EC2? (Public or Private):"
read subnet_type
subnet_type_lower=$(echo "$subnet_type" | tr '[:upper:]' '[:lower:]')

echo "Finding route tables for VPC: $vpc_id"
route_tables=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id --query 'RouteTables[*].RouteTableId' --output text)

# Check each Route Table for Internet Gateway
subnet_ids=()
for rt_id in $route_tables; do
    # Check if the route table has an internet gateway
    has_igw=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[0].Routes[?starts_with(GatewayId, `igw-`)].GatewayId' --output text)

    # If IGW exists (Public route table)
    if [ "$subnet_type_lower" == "public" ] && [ -n "$has_igw" ]; then
        # Fetch the subnets associated with this route table
        associated_subnets=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[].Associations[].SubnetId' --output text)
        subnet_ids+=($associated_subnets)
    fi

    # If NO IGW (Private route table)
    if [ "$subnet_type_lower" == "private" ] && [ -z "$has_igw" ]; then
        # Fetch the subnets associated with this route table
        associated_subnets=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[].Associations[].SubnetId' --output text)
        subnet_ids+=($associated_subnets)
    fi
done

# Display subnets
if [ ${#subnet_ids[@]} -gt 0 ]; then
    echo "Subnets available for $subnet_type subnets:"
    for subnet_id in "${subnet_ids[@]}"; do
        echo "$subnet_id"
    done
else
    echo "No subnets found for the selected type."
fi

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
###################################################################################################################
echo
echo "Choose want to use pre-defined user-data or create custom one:"
echo "1. Use pre-defined Apache Script"
echo "2. Make Custom one"
echo "3. Use the user-data from bash repo"
echo "4. Use S3 Apache Script"
read choice
    case $choice in
        1) 
            user_data_file="Scripts/user_data_scripts/apache.sh"
            ;;
        2)
            echo "Enter full path to your custom user-data script:"
            read custom_path
            user_data_file="$custom_path"
            ;;
        3) 
            user_data_file="Scripts/user_data_scripts/render_markdown.sh"
            ;;
        4)
            user_data_file="Scripts/user_data_scripts/s3_apache.sh"
            ;;

        *)
            echo "Invalid choice. Defaulting to Apache script."
            user_data_file="Scripts/user_data_scripts/apache.sh"
            ;;
    esac



# aws iam create-role --role-name EC2-S3-Access-Role --assume-role-policy-document '{
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }'

# aws iam attach-role-policy --role-name EC2-S3-Access-Role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# aws iam create-instance-profile --instance-profile-name EC2-S3-Profile
# aws iam add-role-to-instance-profile --instance-profile-name EC2-S3-Profile --role-name EC2-S3-Access-Role

# sleep 10



    echo
    echo "Launching EC2 instance..."

    eval "instance_id=$(aws ec2 run-instances \
        --image-id "$ami" \
        --instance-type "$InstanceType" \
        --key-name "$(aws ec2 describe-key-pairs --key-pair-ids "$KeyPairID" --query 'KeyPairs[0].KeyName' --output text)" \
        --subnet-id "$subnet_id_selected" \
        --security-group-ids "$sg" \
        --associate-public-ip-address \
        --count 1 \
        --user-data file://$user_data_file\
        --query 'Instances[0].InstanceId' \
        --output text)"
 # --iam-instance-profile Name=EC2-S3-Profile \
    aws ec2 create-tags \
        --resources "$instance_id" \
        --tags Key=Name,Value="$instance_name"

     echo "EC2 instance $instance_id launched and tagged successfully!"
     ;;
     esac

####################################################################################################################

    # echo
    # echo "Give name to SNS Topic: "
    # read name
    # ARN=$(aws sns create-topic --name $name --query TopicArn --output text)
    # echo "SNS topic created: $ARN"


    # echo "How many SNS Subscribers you want to create?"
    # read num 

    # for i in $(seq 1 $num); do

    #         echo "[$i] Enter the Protocol Service (e.g. email, sms, https): "
    #         read protocol
    #         echo "[$i] Enter the Endpoint (email address, phone in +<countrycode><Phone no.>, http) "
    #         read endpoint
            
    #         subscription_arn=$(aws sns subscribe\
    #         --topic-arn $ARN\
    #         --protocol $protocol\
    #         --notification-endpoint $endpoint\
    #         --query SubscriptionArn --output text)

    #         echo "Subscription created: $subscrition_arn"

    # done

    # echo
    # echo "Enter Message to be Sent to all subscribers: "
    # read Message
    # Id=$(aws sns publish --topic-arn $ARN --message "$Message" --query 'MessageId' --output text)
    # echo "Message sent with ID: $Id"

#####################################################################################################################
    public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[0].Instances[0].PublicIpAddress"\
                --output text)
    echo "Apache server access at: http://$public_ip"



    # echo "Instance will terminate after 10 minutes"
    # (sleep 800 && aws ec2 terminate-instances --instance-id $instance_id && echo "EC2 instance $instance_id terminated. ") &



}

######################################################################################################################

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
