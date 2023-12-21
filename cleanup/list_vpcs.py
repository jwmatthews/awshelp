#!/usr/bin/env python3
import boto3
import pprint

def list_used_vpcs(region):

    ec2 = boto3.client('ec2', region_name=region)

    # Get all VPCs in the region
    vpcs = ec2.describe_vpcs()['Vpcs']
    used_vpcs = []

    for vpc in vpcs:
        vpc_id = vpc['VpcId']

        # Check for EC2 instances in the VPC
        instances = ec2.describe_instances(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
        if any(reservations['Instances'] for reservations in instances['Reservations']):
            used_vpcs.append(vpc_id)

    return used_vpcs

if __name__ == "__main__":
    pp = pprint.PrettyPrinter(indent=2)
    #ec2_global = boto3.client('ec2')
    #regions = [region['RegionName'] for region in ec2_global.describe_regions()['Regions']]
    regions = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2', 'eu-central-1']
    for region in regions:
        used_vpcs = list_used_vpcs(region)
        print(f"{region} has {len(used_vpcs)} VPCs in use:")
        pp.pprint(used_vpcs)
        print("\n\n")

#print("\t", used_vpcs)
