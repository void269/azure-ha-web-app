# Azure Highly Available Web Application

This project deploys a highly available web application environment in Microsoft Azure using Azure Resource Manager (ARM) JSON templates and the Azure CLI.

Incoming HTTP traffic is distributed across multiple virtual machines using an Azure Standard Public Load Balancer. A health probe monitors the backend virtual machines and ensures that application traffic is sent only to healthy instances.

The virtual machines do not have individual public IP addresses. Application traffic and administrative SSH connections are routed through the Azure Load Balancer.

## Architecture

The deployment creates the following Azure resources:

- Resource Group
- Virtual Network
- Application Subnet
- Network Security Group
- Standard Public IP Address
- Standard Public Load Balancer
- Load Balancer Frontend IP Configuration
- Backend Address Pool
- Health Probe
- HTTP Load Balancing Rule
- SSH Inbound NAT Rules
- Multiple Ubuntu Virtual Machines
- Network Interface for each VM
- Azure SSH Public Key resource

Nginx is automatically installed on each virtual machine and used as the web server.

### Traffic Flow

```text
                           Internet
                              |
                              |
                     Public IP Address
                              |
                              v
                   Azure Load Balancer
                    /               \
                   /                 \
            HTTP Port 80         SSH NAT Rules
                 |              50001, 50002...
                 |                    |
          Backend Address Pool        |
             /           \            |
            /             \           |
       web-vm-01       web-vm-02      |
       Private IP      Private IP     |
          |                |          |
        Nginx            Nginx        |
        :80              :80          |
```

Normal HTTP traffic is distributed between healthy backend virtual machines.

SSH traffic uses dedicated Load Balancer inbound NAT ports to connect to a specific VM.

## Project Structure

```text
azure-ha-web-app/
├── README.md
├── LICENSE
├── .gitignore
├── config.env
├── deploy.sh
├── destroy.sh
└── arm/
    ├── network.json
    ├── load-balancer.json
    └── vm.json
```

### Files

| File | Description |
| --- | --- |
| `config.env` | Contains configuration values used by the deployment scripts. |
| `deploy.sh` | Creates the Resource Group, SSH key, networking, Load Balancer, and virtual machines. |
| `destroy.sh` | Deletes the Azure Resource Group and locally stored SSH private key. |
| `arm/network.json` | Creates the VNet, subnet, Network Security Group, and security rules. |
| `arm/load-balancer.json` | Creates the Public IP, Load Balancer, backend pool, health probe, HTTP rule, SSH NAT rules, and outbound rule. |
| `arm/vm.json` | Creates the VM network interfaces and Ubuntu virtual machines and installs Nginx. |

## Prerequisites

The following tools are required:

- Microsoft Azure account
- Azure CLI
- Bash
- jq
- SSH client

Verify the Azure CLI:

```bash
az version
```

Verify `jq`:

```bash
jq --version
```

Log in to Azure:

```bash
az login
```

## Configuration

Deployment settings are stored in:

```text
config.env
```

Example configuration:

```bash
AZURE_SUBSCRIPTION_NAME="Azure subscription 1"

RESOURCE_GROUP="rand-lb-project-rg"
LOCATION="eastus"

SSH_KEY_NAME="rand-vm-ssh-key"
SSH_NAT_PORT_BASE=50000

VNET_NAME="rand-vnet"
VNET_ADDRESS_PREFIX="10.0.0.0/16"

SUBNET_NAME="app-subnet"
SUBNET_PREFIX="10.0.1.0/24"

NSG_NAME="app-nsg"

PUBLIC_IP_NAME="rand-lb-public-ip"

LB_NAME="rand-public-lb"
FRONTEND_NAME="lb-frontend"
BACKEND_POOL_NAME="web-backend-pool"

PROBE_NAME="http-health-probe"
LB_RULE_NAME="http-rule"

VM_COUNT=2
VM_PREFIX="web-vm"
VM_SIZE="Standard_D2als_v7"

ADMIN_USERNAME="azureuser"
```

Modify these values before deployment if different resource names, network ranges, VM sizes, or locations are required.

## Dynamic VM Deployment

The number of virtual machines is controlled by:

```bash
VM_COUNT=2
```

The ARM templates use copy loops to dynamically create the requested number of virtual machines and network interfaces.

For example:

```bash
VM_COUNT=4
```

creates:

```text
web-vm-01
web-vm-02
web-vm-03
web-vm-04
```

Each VM is automatically:

- Connected to the application subnet
- Added to the Load Balancer backend pool
- Configured with an SSH inbound NAT rule
- Configured with the Azure SSH public key
- Configured with Nginx

## Deploy

Make the scripts executable if necessary:

```bash
chmod +x deploy.sh
chmod +x destroy.sh
```

Run:

```bash
./deploy.sh
```

The deployment script will:

1. Select the configured Azure subscription.
2. Verify that the Resource Group does not already exist.
3. Create the Resource Group.
4. Create an Azure SSH public-key resource.
5. Generate a new SSH key pair.
6. Store the private key locally in `.keys/`.
7. Deploy the networking resources.
8. Deploy the Azure Load Balancer.
9. Deploy the virtual machines.
10. Install Nginx on each VM.
11. Display the web application URL.
12. Display the SSH commands for each VM.

After deployment, output similar to the following is displayed:

```text
Deployment complete.

Load Balancer Public IP: 20.x.x.x
Web URL: http://20.x.x.x

SSH private key:
/path/to/azure-ha-web-app/.keys/rand-vm-ssh-key
```

## Load Balancing

HTTP requests are sent to the Azure Load Balancer on:

```text
TCP 80
```

The Load Balancer distributes requests across the healthy virtual machines in its backend pool.

Each VM hosts an Nginx page identifying the VM that handled the request.

For example:

```text
Rand Enterprises
web-vm-01
```

or:

```text
Rand Enterprises
web-vm-02
```

This makes it possible to verify that multiple backend servers are participating in the application.

## Health Probe

The Load Balancer performs health checks against:

```text
TCP 80
```

Only virtual machines that successfully respond to the health probe receive new application traffic.

To test the health probe, SSH into one VM and stop Nginx:

```bash
sudo systemctl stop nginx
```

The Load Balancer will eventually mark that VM unhealthy and stop directing application traffic to it.

The remaining healthy VM will continue serving requests.

Restart Nginx with:

```bash
sudo systemctl start nginx
```

Once the health probe detects that the VM is healthy again, it can resume receiving traffic.

## SSH Access

The virtual machines do not have individual public IP addresses.

Instead, SSH connections use inbound NAT rules on the Azure Load Balancer.

The NAT port is calculated using:

```text
SSH_NAT_PORT_BASE + VM number
```

With:

```bash
SSH_NAT_PORT_BASE=50000
```

the following mappings are created:

| VM | Load Balancer Port | VM Port |
| --- | ---: | ---: |
| `web-vm-01` | `50001` | `22` |
| `web-vm-02` | `50002` | `22` |
| `web-vm-03` | `50003` | `22` |
| `web-vm-04` | `50004` | `22` |

For example, connect to VM 01 with:

```bash
ssh -i ./.keys/rand-vm-ssh-key \
    -p 50001 \
    azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

Connect to VM 02 with:

```bash
ssh -i ./.keys/rand-vm-ssh-key \
    -p 50002 \
    azureuser@<LOAD_BALANCER_PUBLIC_IP>
```

## SSH Key Management

A new SSH key pair is generated during deployment.

The public key is stored as an Azure SSH Public Key resource inside the project's Resource Group.

The private key is saved locally under:

```text
.keys/
```

For example:

```text
.keys/rand-vm-ssh-key
```

The `.keys` directory is excluded from Git using `.gitignore`.

**Never commit the SSH private key to GitHub.**

When `destroy.sh` is run:

- The Azure SSH Public Key resource is deleted with the Resource Group.
- The local private key is deleted.
- The `.keys` directory is removed if empty.

A new key pair is generated the next time the environment is deployed.

## Destroy

To remove the environment:

```bash
./destroy.sh
```

The script initiates deletion of the Resource Group and waits for Azure to finish removing the resources.

Progress is displayed while deletion is taking place:

```text
Deleting all resources associated with Resource Group: rand-lb-project-rg

Waiting for Resource Group deletion to complete...
Resources remaining: 12
Resources remaining: 8
Resources remaining: 5
Resources remaining: 2
Resources remaining: 0

Resource Group deleted.

Local SSH private key deleted.

Deletion complete.
```

Deleting the Resource Group removes all Azure resources created by the project.

## Security

The virtual machines are not assigned individual public IP addresses.

Public application traffic reaches the backend servers through the Azure Load Balancer.

SSH access also passes through the Load Balancer using dedicated inbound NAT rules.

The Network Security Group allows:

| Traffic | Protocol | Port |
| --- | --- | ---: |
| HTTP | TCP | 80 |
| Load Balancer Health Probe | TCP | 80 |
| SSH | TCP | 22 |

For additional security, SSH access can be restricted to a specific public IP address instead of allowing connections from the entire Internet.

## High Availability

The architecture improves application availability by combining:

- Multiple web server instances
- Azure Load Balancer
- Backend address pool
- Health monitoring
- Automatic removal of unhealthy instances from traffic distribution

If one web server becomes unhealthy, the Load Balancer continues directing application requests to the remaining healthy instances.

This allows the application to continue serving users without requiring the failed VM to be manually removed from the Load Balancer.

## Cleanup

Azure resources may continue to generate charges while they exist.

When finished testing the project, run:

```bash
./destroy.sh
```

Verify that the Resource Group has been removed:

```bash
az group exists \
    --name rand-lb-project-rg
```

A successful deletion returns:

```text
false
```

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.