# Overview
Notes on cleaning up AWS resources

## EKS
* From API:
    * Unable to delete an EKS cluster that I didn't provision, or not configured to access with OIDC for k8s API, so falling back to WebUI
* From WebUI:
    * When trying to delete an EKS cluster the NodeGroups need to be deleted first.
    * WebUI will guide to delete the NodeGroup from the Cluster's Compute page.  
        * Takes several minutes for NodeGroup to be cleaned up
