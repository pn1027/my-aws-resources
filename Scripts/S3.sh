
#!/bin/bash

create_s3() {
    default_bucket_name="ec2-website-bucket-07"
    
    echo "Enter S3 bucket name (or press Enter for default: $default_bucket_name):"
    read bucket_name
    if [ -z "$bucket_name" ]; then
        bucket_name="$default_bucket_name"
    fi
    
    echo "Creating S3 bucket: $bucket_name"
    aws s3 mb s3://$bucket_name
    
    if [ $? -eq 0 ]; then
        echo "S3 bucket created successfully: $bucket_name"
        
        echo "Creating index.html"
        echo "<html><body><h1>Hello from S3 Bucket!</h1></body></html>" > index.html
        
        echo "Uploading index.html"
        aws s3 cp index.html s3://$bucket_name/
        
         aws s3api put-public-access-block --bucket $bucket_name --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
        echo "Creating bucket policy for public access to objects"
        policy='{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "PublicReadGetObject",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::'$bucket_name'/*"
                }
            ]
        }'
        

        aws s3api put-bucket-policy --bucket $bucket_name --policy "$policy"
        

        echo "Storing bucket name in a local file"
        echo "$bucket_name" > s3_bucket_name.txt
        

        rm index.html
        
        echo "Bucket URL: https://$bucket_name.s3.amazonaws.com/index.html"
    else
        echo "Failed to create S3 bucket."
    fi
}

#####################################################################################################################

delete_s3() {
    # List available buckets
    echo "Available S3 buckets:"
    aws s3 ls
    
    echo "Enter the name of the S3 bucket to delete:"
    read bucket_name
    
    # Confirm deletion
    echo "Are you sure you want to delete bucket '$bucket_name' and all its contents? (y/n)"
    read confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        # Empty the bucket first
        echo "Emptying bucket contents..."
        aws s3 rm s3://$bucket_name --recursive
        
        # Delete the bucket
        echo "Deleting bucket..."
        aws s3 rb s3://$bucket_name
        
        echo "S3 bucket deleted successfully!"
    else
        echo "Deletion cancelled."
    fi
}