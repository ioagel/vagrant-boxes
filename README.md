# README

## Requirements

- `Linux` ;-)
- `Virtualbox`
- `Vagrant`
- `Ansible`

  Create a Python 3 env: `python3 -m venv .venv && source .venv/bin/activate`
    - run: `pip install -r requirements.txt`
    - run: `ansible-galaxy install -r collections/requirements.yml`

## Create all Boxes workflow

```sh
# Download latest cloud images
./setup.sh download_latest
# create the vms in Virtualbox
./setup.sh create_vm ubuntu22.04 ubuntu22.04/ubuntu-22.04-server-cloudimg-amd64.img
./setup.sh create_vm debian12 debian12/debian-12-generic-amd64.raw
# Configure the vms using ansible
./setup.sh prepare_vm
# Create local boxes and add them to vagrant for testing
./setup.sh create_box ubuntu22.04
./setup.sh create_box debian12
# Clean up the vms
./setup clean ubuntu22.04
./setup clean debian12
```

For more options check: `setup.sh`
