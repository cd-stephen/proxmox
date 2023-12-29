#!/bin/bash

###################################################################
#                  proxmox scripted vm deployer                   #
###################################################################

###  copy this file to /root/deploy.sh on proxmox server (cd-pve01) ###

# commands to customize the image // not needed
# sudo virt-customize -a jammy-server-cloudimg-amd64.img --install qemu-guest-agent
# sudo virt-customize -a jammy-server-cloudimg-amd64.img --root-password password:password

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# Check if the hostname contains the string "pve"
if [[ ! $(hostname) == *pve* ]]; then
  echo "Error: This script must be run on a proxmox host."
  exit 1
fi

# Get the script's directory
script_dir="$(dirname "$0")"

# Check if 'cloud-localds' exists in the script's directory
if [ ! -f "$script_dir/cloud-localds" ]; then
  echo "Error: 'cloud-localds' must exist in the script's directory."
  exit 1
fi

# Continue with the rest of the script
echo "Running script as root on a proxmox host, 'cloud-localds' found..."

# Function to display help message
display_help() {
  clear
  echo "Usage: $0 [options]"
  echo " -i VMID          :: unique number >= 100 for the virtual machine. ie #### # = vlanID 1103 = 3 -> ### = IP Host"
  echo " -h HOSTNAME      :: valid hostname of the virtual maching in cloudinit. ie cd-server01"
  echo " -c CPU           :: number of hypervisor host cpu cores to allocate. ie 2"
  echo " -m MEMORY        :: MiB of memory to allocate to the virtual machine. ie 1024, 2048, 4096, 8192, 16384, 32768, 65536"
  echo " -d DISKSIZE      :: size of boot drive for scsi0. ie 10G, 32G, 100G"
  echo " -n NETWORK       :: vlanID of the vmbr1 device. ie 99, 1101, 1101, 1102, 1103"
  echo ''
  echo "Sample: ./deploy.sh -i 999 -h server01 -c 2 -m 2048 -d 32G -n 99"
  echo ''
  echo ''
  exit 1
}

# Parse options
while getopts i:h:c:m:d:n: flag; do
  case "${flag}" in
    i) vmid=${OPTARG} ;;
    h) hostname=${OPTARG} ;;
    c) cpu=${OPTARG} ;;
    m) memory=${OPTARG} ;;
    d) disksize=${OPTARG} ;;
    n) network=${OPTARG} ;;
    *) display_help ;;
  esac
done

# Validate VMID - it must be numeric and greater than 100
if ! [[ "$vmid" =~ ^[0-9]+$ ]] || [ "$vmid" -le 100 ]; then
  echo "Error: VMID must be a numeric value greater than 100"
  sleep 2
  display_help
fi

# Check if essential variables are set, else display help
if [ -z "$vmid" ] || [ -z "$hostname" ] || [ -z "$cpu" ] || [ -z "$memory" ] || [ -z "$disksize" ] || [ -z "$network" ]; then
  display_help
fi

# Clear screen and echo the provided arguments
clear
echo ''
echo ''
echo 'Building VM with following arguments:'
echo "ID: ............ $vmid"
echo "Hostname: ...... $hostname"
echo "CPU: ........... $cpu"
echo "Memory: ........ $memory"
echo "Disksize: ...... $disksize"
echo "Network: ....... $network"
echo ''
echo ''
sleep 2

# Continue with the rest of your script

# Check if status command returned anything
# Get status of specific VM
status=$(qm status $vmid)

# Check if 'status' is in the $status variable
if [[ $status == *"status"* ]]; then
    echo "VM with ID $vmid exists with status: $status. Exiting."
    exit 0
else
    echo "VM with ID $vmid does not exist. Proceeding with other operations."
    
fi

# Define File Paths for cloud-init user, network, and meta(optional)
userdata_file="/mnt/pve/pve-guests/snippets/userdata-$hostname.yaml"
network_file="/mnt/pve/pve-guests/snippets/network-$hostname.yaml"

# Function to check and remove file
check_and_remove() {
  echo '### checking for old cloudinit snippets ###'
  if [ -e "$1" ]; then
    echo "File $1 exists. Removing..."
    rm -rf "$1"
  else
    echo "File $1 does not exist."
  fi
}
check_and_remove

# Define source and destination paths for userdata
src_userdata_file="/mnt/pve/pve-iso/template/iso/cloudinit/$hostname/userdata.yaml"
dest_userdata_file="/mnt/pve/pve-guests/snippets/userdata-$hostname.yaml"

# Define source and destination paths for network
src_network_file="/mnt/pve/pve-iso/template/iso/cloudinit/$hostname/network.yaml"
dest_network_file="/mnt/pve/pve-guests/snippets/network-$hostname.yaml"

# Function to check and copy file
check_and_copy() {
  echo '### checking for new cloudinit userdata.yaml and network.yaml ###'
  if [ -e "$1" ]; then
    echo "Source file $1 exists. Copying to $2..."
    cp "$1" "$2"
  else
    echo "Error: Source file $1 does not exist."
    # Exit with code 1 (or other non-zero exit code) to indicate error
    exit 1
  fi
}

# Call function with specified files
check_and_copy "$src_userdata_file" "$dest_userdata_file"
check_and_copy "$src_network_file" "$dest_network_file"

echo '';
echo 'creating virtual machine';

qm create $vmid --name $hostname --ostype l26 --machine q35 --bios ovmf \
--agent 1,fstrim_cloned_disks=1 --cores $cpu --cpu host --memory $memory --numa 0 --scsihw virtio-scsi-single
if [ $? -ne 0 ]; then
  echo "Error: Failed to create VM with ID $vmid and name $hostname"
  exit 1
fi

# create scsi0 boot from cloudimage
qm importdisk $vmid /mnt/pve/pve-iso/template/iso/jammy-server-cloudimg-amd64.img pve-guests --format qcow2
if [ $? -ne 0 ]; then
  echo "Error: Failed to create OS disk from cloudimage for ID $vmid and name $hostname"
  exit 1
fi
qm set $vmid --scsi0 pve-guests:$vmid/vm-$vmid-disk-0.qcow2,discard=on,iothread=1
qm resize $vmid scsi0 $disksize

# create efi disk
qemu-img create -f qcow2 /mnt/pve/pve-guests/images/$vmid/vm-${vmid}-disk-efi0.qcow2 528K
if [ $? -ne 0 ]; then
  echo "Error: Failed to create EFI disk for ID $vmid and name $hostname"
  exit 1
fi
qm set $vmid --efidisk0 pve-guests:$vmid/vm-$vmid-disk-efi0.qcow2,size=528K

# create networking
qm set $vmid --net0 virtio,bridge=vmbr1,firewall=0,mtu=1,tag=$network

# create additional i/o and configs
qm set $vmid --serial0 socket --vga serial0
qm set $vmid --ide2 local-lvm:cloudinit
qm set $vmid --boot c --bootdisk scsi0
qm set $vmid --cicustom user=pve-guests:snippets/userdata-$hostname.yaml,network=pve-guests:snippets/network-$hostname.yaml

# boot and connect to terminal via serial
qm start $vmid
qm terminal $vmid
# Ctrl+O to exit terminal
