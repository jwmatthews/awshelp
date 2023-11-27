#!/usr/bin/env python

import boto3

def list_instance_profiles():
    iam_client = boto3.client('iam')
    paginator = iam_client.get_paginator('list_instance_profiles')

    for page in paginator.paginate():
        for profile in page['InstanceProfiles']:
            print(f"{profile['InstanceProfileName']}")
            print(f"{profile}")

if __name__ == "__main__":
    list_instance_profiles()




