# Create an EKS Cluster

This directory will help you deploy an EKS Cluster with the [EBS CSI AddOn](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) configured.  It relies heavily on the [aws](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html) CLI tools

## Setup
* One time setup steps so you can use these scripts
### Create `my_override_vars.yml`
* ```
   cp my_override_vars.yml.example my_override_vars.yml
   ```
* Edit `my_override_vars.yml`
  * Change the value of 'my_name' to a unique value with your name to help identify if in a shared AWS account:  Example I use "jmatthews"
  * If needed, edit the 'region_name' or other attributes if you want to customize
  * Note this file is intentionally ignored in git via .gitignore
### Setup python venv with Ansible requirements
* Setup the python venv and install the needed ansible requirements by running:
  ```
  ./init.sh
  ```
    *  If you need to update the venv requirements, run: `pip3 freeze > requirements.txt`
### AWS Client setup
1. Install the `aws` CLI tool
   * See:  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
1. Install the `eksctl` CLI tool
   * See: https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html
1. Configure your AWS credentials so they are available in the shell
   * See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

## Provision EKS Cluster
Run
```
./create_infra.sh
```
   * This will take on order of ~20 minutes

## Deprovision EKS Cluster
Run 
```
./delete_infra.sh
```
   * This will take on order of ~10 minutes