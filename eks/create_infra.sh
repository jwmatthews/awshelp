#Set to 1 or higher to see more info on intermediate steps
#export ANSIBLE_VERBOSITY=0

ansible-playbook create_infra.yml --extra-vars "@eks_vars.yml" --extra-vars "@my_override_vars.yml"
