# proxmox
proxmox and kvm related scripts and tools
# Proxmox Deploy

This repository contains scripts for deploying Proxmox virtual machines using cloud-init.

## Prerequisites

- Proxmox VE installed on the target server
- Cloud-init package installed on the target server

## Usage

1. Clone this repository to your local machine:

  ```bash
  git clone https://github.com/your-username/proxmox-deploy.git
  ```

2. Customize the cloud-init configuration file according to your needs. You can find the file at `cloud-init/user-data.yaml`.

3. Deploy a new Proxmox virtual machine using the following command:

  ```bash
  ./deploy.sh
  ```

  This script will create a new virtual machine on the Proxmox server and configure it using the cloud-init configuration.

4. Access the deployed virtual machine using SSH:

  ```bash
  ssh user@<vm-ip-address>
  ```

  Replace `<vm-ip-address>` with the IP address of the deployed virtual machine.

## Contributing

Contributions are welcome! If you have any improvements or bug fixes, feel free to open a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
