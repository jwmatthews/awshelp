#!/usr/bin/env python3

import boto3

def list_eks_clusters():
    ec2 = boto3.client('ec2')
    regions = [region['RegionName'] for region in ec2.describe_regions()['Regions']]

    all_eks_clusters = {}

    for region in regions:
        eks = boto3.client('eks', region_name=region)

        # Get the names of all EKS clusters in the region
        cluster_names = eks.list_clusters()['clusters']

        for cluster_name in cluster_names:
            # Get the details of each cluster
            cluster_info = eks.describe_cluster(name=cluster_name)
            cluster_status = cluster_info['cluster']['status']

            if cluster_status == 'ACTIVE':
                if region not in all_eks_clusters:
                    all_eks_clusters[region] = []
                all_eks_clusters[region].append(cluster_name)

    return all_eks_clusters

# Example usage
eks_clusters = list_eks_clusters()
for region, clusters in eks_clusters.items():
    print(f"Region: {region}, EKS Clusters: {clusters}")
