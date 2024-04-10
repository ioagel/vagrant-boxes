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
# Create everything
./setup.sh all
# or Create everything without downloading the images
./setup.sh all --no-downloads
# Push the boxes to Vagrant Cloud
./setup.sh publish
# Clean up everything
./setup.sh clean
```

For more options check: `setup.sh`
