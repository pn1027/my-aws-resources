echo "Give Launch Template Name: " 
read name

aws ec2 create-launch-template --launch-template-name $name --version-description "version 1" \
--launch-template-data file://Scripts/ec2_config.json

# To convert a script to Base 64 for JSNO
# base64 -w 0 Scripts/user_data_scripts/apache.sh
aws ec2 describe-vpcs --query 'Vpcs[*].{Id: VpcId, Name: Tags[?Key==`Name`] | [0].Value}'  --output table
echo "Enter VPC ID: "
read vpc_id

rt_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id --query "RouteTables[?Routes[?starts_with(GatewayId, 'igw-')]].RouteTableId" --output text)
public_subnets=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query 'RouteTables[].Associations[?SubnetId].SubnetId' --output text)
public_subnets=$(echo $public_subnets | tr ' ' ',')

echo
echo "Available Launch Templates"
aws ec2 describe-launch-templates --query 'LaunchTemplates[*].{Name: LaunchTemplateName, Id: LaunchTemplateId}' --output json

aws autoscaling create-auto-scaling-group \
--auto-scaling-group-name Auto-Scaling-ALB \
--launch-template LaunchTemplateName=$name,Version='1' \
--min-size 1 \
--max-size 3 \
--desired-capacity 1 \
--vpc-zone-identifier "$public_subnets"










