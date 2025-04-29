#!/bin/bash

source ./Scripts/vpc.sh
source ./Scripts/ec2.sh


# Dispatcher to call functions by name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ -z "$1" ]]; then
    echo "Choose an option:"
    echo "1) Create VPC"
    echo "2) Show VPCs"
    echo "3) Delete VPC"
    echo "4) Create EC2 Instance"
    echo "5) Delete EC2 Instance"
    read -rp "Enter choice [1-5]: " choice

    case $choice in
      1)
        echo
        # echo -n "Enter min value for random number (default 1): "
        # read min
        # echo -n "Enter max value for random number (default 1000): "
        # read max
        create_vpc 
        # "${min:-1}" "${max:-1000}"
        ;;
      2)
        echo
        show_vpc
        ;;
      3)
        echo
        aws ec2 describe-vpcs --query 'Vpcs[*].{Id: VpcId, Name: Tags[?Key==`Name`] | [0].Value}'  --output table
        echo -n "Enter VPC ID to delete: "
        read vpc_id
        delete_vpc_resources "$vpc_id"
        ;;
      4)
        echo
        create_ec2
        ;;
      5)
        echo
        ec2_delete
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