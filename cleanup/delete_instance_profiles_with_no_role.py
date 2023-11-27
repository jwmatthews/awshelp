#!/usr/bin/env python

import boto3

def delete_instance_profiles_with_no_roles():
    iam_client = boto3.client('iam')
    paginator = iam_client.get_paginator('list_instance_profiles')

    for page in paginator.paginate():
        for profile in page['InstanceProfiles']:
            if len(profile['Roles']) == 0:
                print(f"{profile['InstanceProfileName']} has no roles")
                iam_client.delete_instance_profile(InstanceProfileName=profile['InstanceProfileName'])

if __name__ == "__main__":
    delete_instance_profiles_with_no_roles()




