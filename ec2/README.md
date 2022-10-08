# Create an EC2 Environment

This repository contains ansible automation to create a number of ec2 instances and configure them to use for hacking on various projects
* Create a CentOS8 instance
* Install CRIO
* Install Podman
* Install minikube and set podman as default driver
* Check out a few git repos to make life easier


## Expectations 
* This automation assumes you have ec2 access and your [AWS environment variables are set](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
* We will create all ec2 resources with a name pattern based on `project_tag` in [my_vars.yml](my_vars.yml) 
* SSH access to instances will be possible using the username `centos` and the ssh key in the `./keys` local directory
   * Note:  The SSH key will be downloaded *only* if it did not previously exist in the specific AWS region, i.e. the SSH private key is only downloaded when it is created, subsequent runs will use the ssh public key information in AWS.  If you don't save the SSH private key you will *not* be able to access your instances.

# Pre-provisioning Steps
## On MacOS
 * Install rustup to satisfy reqs for python cryptography package building
 * Install 'openssl':  `brew install openssl`


## All Platforms
 * You can run `init.sh` which will execute the below commands
   * Install Virtualenv
      ```
      python3 -m venv env
      ```

   * Activate Virtualenv and install requirements
      ```
      source env/bin/activate
      pip3 install -r requirements.txt
      ```
   
   * Install Ansible collections
     ```
     ansible-galaxy install -r requirements.yml	
     ```

## To Update the requirements
   ```
   pip3 freeze > requirements.txt
   ``` 

# Usage
## Customizations
 * If you want to run this for yourself without stepping on anyone else, then change the below:
   * Edit [my_vars.yml](my_vars.yml) and change the value of `project_tag` to something unique
   * Update [lab_hosts.aws_ec2.yml](lab_hosts.aws_ec2.yml) and change this line "`- jwm_tmp_crane_hackfest*`" to match your new `project_tag` 

## To create the environments
1. ./create_infra.sh
2. ./setup_nodes.sh
3. ssh into an instance and use: `ssh -i keys/mykeyname.pem centos@ec2-example-compute-1.amazonaws.com`
   * note the usage of `centos` as user name

## To delete the environments
1. ./delete_infra.sh

