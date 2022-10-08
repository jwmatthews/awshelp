gist -p -f ssh_hackfest.pem -u https://gist.github.com/jwmatthews/8bce7b7519753a7044b85dafa3ae5287 ./keys/jwm_tmp_crane_hackfest_us-east-1.pem
ansible-inventory -i lab_hosts.aws_ec2.yml --list &> inventory.json
./update_spreadsheet.py

