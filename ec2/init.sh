#python3 -m pip install --user virtualenv
python3 -m venv env
source env/bin/activate
pip3 install -r requirements.txt
ansible-galaxy install -r requirements.yml --ignore-certs


