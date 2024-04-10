#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

export PATH="./scripts:$PATH"

ubuntu_vm="ubuntu22.04"
ubuntu_img="./ubuntu22.04/ubuntu-22.04-server-cloudimg-amd64.img"
debian_vm="debian12"
debian_img="./debian12/debian-12-generic-amd64.raw"

case "$1" in
"all")
  if [ -z "$2" ] || [ "$2" != "--no-downloads" ]; then
    ./setup.sh download_latest
  fi
  ./setup.sh create_vm
  ./setup.sh prepare_vm
  ./setup.sh create_box
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
"create_vm")
  shift 1
  if [ -n "$1" ]; then
    case "$1" in
    "$debian_vm")
      shift 1
      setup_vbox_vm.sh "$debian_vm" "$debian_img" "$@"
      ;;
    "$ubuntu_vm")
      shift 1
      setup_vbox_vm.sh "$ubuntu_vm" "$ubuntu_img" "$@"
      ;;
    *)
      # we want to create both vms at the same time, with passing some options
      setup_vbox_vm.sh "$debian_vm" "$debian_img" "$@"
      setup_vbox_vm.sh "$ubuntu_vm" "$ubuntu_img" "$@"
      ;;
    esac
  else
    # we want to create both vms at the same time, without passing any options, using default values
    setup_vbox_vm.sh "$debian_vm" "$debian_img"
    setup_vbox_vm.sh "$ubuntu_vm" "$ubuntu_img"
  fi
  ;;
"prepare_vm")
  # you can pass any number of ansible arguments
  # i.e. to remove snapd: ./setup.sh prepare_vm --extra-vars(or '-e') "remove_snapd=true"
  shift 1
  # Depending on the OS if it exists as first argument, we need to pass a limit to ansible-playbook
  if [ -n "$1" ]; then
    case "$1" in
    "$debian_vm")
      shift 1
      ansible-playbook setup_host.yml -l "$debian_vm" "$@"
      ;;
    "$ubuntu_vm")
      shift 1
      ansible-playbook setup_host.yml -l "$ubuntu_vm" "$@"
      ;;
    *)
      # Invalid argument
      echo -e "${RED}Invalid argument: $1, use either '$ubuntu_vm' or '$debian_vm'${ENDCOLOR}"
      exit 1
      ;;
    esac
  else
    # we want to prepare both vms at the same time
    ansible-playbook setup_host.yml "$@"
  fi
  ;;
"create_box")
  shift 1
  if [ -n "$1" ]; then
    case "$1" in
    "$debian_vm")
      create_box.sh "$debian_vm"
      ;;
    "$ubuntu_vm")
      create_box.sh "$ubuntu_vm"
      ;;
    *)
      # Invalid argument
      echo -e "${RED}Invalid argument: $1, use either '$ubuntu_vm' or '$debian_vm'${ENDCOLOR}"
      exit 1
      ;;
    esac
  else
    # we want to create both boxes at the same time
    create_box.sh "$debian_vm"
    create_box.sh "$ubuntu_vm"
  fi
  ;;
"clean")
  shift 1
  if [ -n "$1" ]; then
    case "$1" in
    "$debian_vm")
      clean_up.sh "$debian_vm"
      ;;
    "$ubuntu_vm")
      clean_up.sh "$ubuntu_vm"
      ;;
    *)
      # Invalid argument
      echo -e "${RED}Invalid argument: $1, use either '$ubuntu_vm' or '$debian_vm'${ENDCOLOR}"
      exit 1
      ;;
    esac
  else
    # we want to remove both boxes at the same time
    clean_up.sh "$debian_vm"
    clean_up.sh "$ubuntu_vm"
  fi
  ;;
"publish")
  shift 1
  if [ -z "$1" ]; then
    echo -e "${RED}Please provide the box name to publish${ENDCOLOR}"
    exit 1
  fi
  . "${1}/vars"
  box="${1}/package-${BOX_VERSION}.box"
  checksum=$(sha256sum "${box}" | awk '{print $1}')
  whoami=$(vagrant cloud auth whoami --no-tty | awk '{print $5}')
  vagrant cloud publish -f -c "$checksum" -C sha256 --no-private "$whoami"/"$1" "$BOX_VERSION" virtualbox "$box"
  echo -e "${RED}Need to set description and release it!${ENDCOLOR}"
  ;;
*)
  echo -e "\nSelect appropriate action:\n"
  echo -e "            ${GREEN}all${ENDCOLOR}:  Run everything except for publish: ./setup.sh all <--no-downloads>\n"
  echo -e "      ${GREEN}create_vm${ENDCOLOR}:  Create and run the virtualbox vm (download the images before running this command)\n \
     ubuntu 22.04:  ./setup.sh create_vm ubuntu22.04\n \
        debian 12:  ./setup.sh create_vm debian12\n \
        both vms:  ./setup.sh create_vm\n"
  echo -e "     ${GREEN}prepare_vm${ENDCOLOR}:  Prepare the vm using ansible\n"
  echo -e "     ${GREEN}create_box${ENDCOLOR}:  Convert the vm to a vagrant box: ./setup.sh create_box <debian12 | ubuntu22.04>\n"
  echo -e "${GREEN}download_latest${ENDCOLOR}:  Download the latest debian 12 and ubuntu 22.04 images\n"
  echo -e "          ${GREEN}clean${ENDCOLOR}:  Destroy and remove the vm and it's resources: ./setup.sh clean <debian12 | ubuntu22.04>\n"
  echo -e "        ${GREEN}publish${ENDCOLOR}:  Publish the box to vagrant cloud (you need to be logged in): ./setup.sh publish <debian12 | ubuntu22.04>\n"
  echo -e "Usage: ${GREEN}./setup.sh${ENDCOLOR} <all | create_vm | prepare_vm | create_box | download_latest | clean | publish>"
  exit 1
  ;;
esac

exit 0
