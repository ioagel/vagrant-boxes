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
    echo -e "${GREEN}Cleaning old files ...${ENDCOLOR}"
    rm -f ./ubuntu22.04/*.img
    rm -f ./debian12/*.raw
    rm -f ./files/vboxtools.iso
    echo -e "${GREEN}Downloading latest ubuntu 22.04 image ...${ENDCOLOR}"
    wget -P ./ubuntu22.04 https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img
    echo -e "${GREEN}Downloading latest debian 12 image ...${ENDCOLOR}"
    wget -P ./debian12 https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.raw
    guest_tools_latest=$(curl https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT)
    echo -e "${GREEN}Downloading latest stable Virtualbox tools ${guest_tools_latest} ...${ENDCOLOR}"
    wget https://download.virtualbox.org/virtualbox/"${guest_tools_latest}"/VBoxGuestAdditions_"${guest_tools_latest}".iso \
        -O ./files/vboxtools.iso
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
    echo -e "\nSelect appropriate action:\n"
    echo -e "      ${GREEN}create_vm${ENDCOLOR}:  Create and run the virtualbox vm (download the images before running this command)\n \
     ubuntu 22.04:  ./setup.sh create_vm ubuntu22.04 ubuntu22.04/ubuntu-22.04-server-cloudimg-amd64.img\n \
        debian 12:  ./setup.sh create_vm debian12 debian12/debian-12-generic-amd64.raw\n"
    echo -e "     ${GREEN}prepare_vm${ENDCOLOR}:  Prepare the vm using ansible\n"
    echo -e "     ${GREEN}create_box${ENDCOLOR}:  Convert the vm to a vagrant box: ./setup.sh create_box <debian12 | ubuntu22.04>\n"
    echo -e "${GREEN}download_latest${ENDCOLOR}:  Download the latest debian 12 and ubuntu 22.04 images\n"
    echo -e "          ${GREEN}clean${ENDCOLOR}:  Destroy and remove the vm and it's resources: ./setup.sh clean <debian12 | ubuntu22.04>\n"
    echo -e "        ${GREEN}publish${ENDCOLOR}:  Publish the box to vagrant cloud (you need to be logged in): ./setup.sh publish <debian12 | ubuntu22.04>\n"
    echo -e "Usage: ${GREEN}./setup.sh${ENDCOLOR} <create_vm | prepare_vm | create_box | download_latest | clean | publish>"
    exit 1
    ;;
esac

exit 0
