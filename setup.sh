#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

export PATH="./scripts:$PATH"

case "$1" in
  "create_vm")
    shift 1
    setup_vbox_vm.sh "$@"
    ;;
  "prepare_vm")
    ansible-playbook setup_host.yml
    ;;
  "create_box")
    shift 1
    create_box.sh "$@"
    ;;
  "download_latest")
    echo -e "${GREEN}Cleaning old images ...${ENDCOLOR}"
    rm -f ./ubuntu22.04/*.img
    rm -f ./debian12/*.raw
    echo -e "${GREEN}Downloading latest ubuntu 22.04 image ...${ENDCOLOR}"
    wget -P ./ubuntu22.04 https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img
    echo -e "${GREEN}Downloading latest debian 12 image ...${ENDCOLOR}"
    wget -P ./debian12 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.raw
    ;;
  "clean")
    shift 1
    clean_up.sh "$@"
    ;;
  "publish")
    shift 1
    . "${1}/vars"
    box="${1}/package-${BOX_VERSION}.box"
    checksum=$(sha256sum "${box}" | awk '{print $1}')
    whoami=$(vagrant cloud auth whoami --no-tty | awk '{print $5}')
    vagrant cloud publish -f -c "$checksum" -C sha256 --no-private "$whoami"/"$1" "$BOX_VERSION" virtualbox "$box"
    echo -e "${RED}Need to set description and release it!${ENDCOLOR}"
    ;;
  *)
    printf "\nSelect appropriate action:\n"
    printf "      create_vm:  Create and run the virtualbox vm\n"
    printf "     prepare_vm:  Prepare the vm using ansible\n"
    printf "     create_box:  Convert the vm to a vagrant box\n"
    printf "download_latest:  Download the latest debian 12 and ubuntu 22.04 images\n"
    printf "          clean:  Destroy and remove the vm and it's resources\n"
    echo "Usage: ./setup.sh <create_vm | prepare_vm | create_box | download_latest | clean>"
    exit 1
    ;;
esac

exit 0
