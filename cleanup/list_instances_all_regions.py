#!/usr/bin/env python3
import boto3

def list_instances_in_all_regions():
    ec2_global = boto3.client('ec2')
    regions = [region['RegionName'] for region in ec2_global.describe_regions()['Regions']]

    all_instances = {}

    for region in regions:
        ec2 = boto3.client('ec2', region_name=region)

        # Describe all instances
        instances = ec2.describe_instances()
        used_instances = []

        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                # You can adjust this condition to change what you consider 'in use'
                if instance['State']['Name'] == 'running':
                    used_instances.append(instance['InstanceId'])

        if used_instances:
            all_instances[region] = used_instances

    return all_instances

# Example usage
instances = list_instances_in_all_regions()
for region, instance_ids in instances.items():
    print(f"Region: {region} has {len(instance_ids)} instances running")
