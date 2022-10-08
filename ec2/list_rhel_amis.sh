# see https://access.redhat.com/solutions/15356
aws ec2 describe-images --owners 309956199498 --query 'sort_by(Images, &CreationDate)[*].[CreationDate,Name,ImageId]' --filters "Name=name,Values=RHEL-8*" --region us-east-1 --output table

