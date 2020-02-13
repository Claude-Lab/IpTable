#!/bin/sh

##### Changing ip and ports #####

#     _____________________________________________
#     |       To replace        |      Lines      |
#     _____________________________________________
#     |     Public IP           |        41       |
#     |     SSH port            |       107       |
#     |     WebUI port          |       109       |
#     |     SSH port            |       122       |
#     |     SSH port            |       133       |
#     |     WebUI port          |       135       |
#     |     SSH & WebUI ports   |       153       |
#     |     SSH port            |       165       |
#     |     WebUI port          |       168       |
#     |     SSH port            |       174       |
#     |     WebUI port          |       176       |
#     |___________________________________________|


	# ---------
	# VARIABLES
	# ---------

## Proxmox bridge holding Public IP
PrxPubVBR="vmbr0"
## Proxmox bridge on VmWanNET (PFSense WAN side)
PrxVmWanVBR="vmbr1"
## Proxmox bridge on PrivNET (PFSense LAN side)
PrxVmPrivVBR="vmbr2"

## Network/Mask of VmWanNET
VmWanNET="10.0.0.0/30"
## Network/Mmask of PrivNET
PrivNET="192.168.9.0/24"
## Network/Mmask of VpnNET
VpnNET="10.2.2.0/24"

## Public IP => Set your own
PublicIP="xx.xx.xx.xx"
## Proxmox IP on the same network than PFSense WAN (VmWanNET)
ProxVmWanIP="10.0.0.1"
## Proxmox IP on the same network than VMs
ProxVmPrivIP="192.168.9.1"
## PFSense IP used by the firewall (inside VM)
PfsVmWanIP="10.0.0.2"


	# ---------------------
	# CLEAN ALL & DROP IPV6
	# ---------------------

### Delete all existing rules.
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
### This policy does not handle IPv6 traffic except to drop it.
ip6tables -P INPUT DROP
ip6tables -P OUTPUT DROP
ip6tables -P FORWARD DROP

	# --------------
	# DEFAULT POLICY
	# --------------

### Block ALL !
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

	# ------
	# CHAINS
	# ------

### Creating chains
iptables -N TCP
iptables -N UDP

# UDP = ACCEPT / SEND TO THIS CHAIN
iptables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
# TCP = ACCEPT / SEND TO THIS CHAIN
iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP

	# ------------
	# GLOBAL RULES
	# ------------

# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
# Don't break the current/active connections
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Allow Ping - Comment this to return timeout to ping request
iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT

	# --------------------
	# RULES FOR PrxPubVBR
	# --------------------

### INPUT RULES
# ---------------

# Allow SSH server - Set port for SSH
iptables -A TCP -i $PrxPubVBR -d $PublicIP -p tcp --dport XX -j ACCEPT
# Allow Proxmox WebUI - Set port for WebUI
iptables -A TCP -i $PrxPubVBR -d $PublicIP -p tcp --dport XX -j ACCEPT

### OUTPUT RULES
# ---------------

# Allow ping out
iptables -A OUTPUT -p icmp -j ACCEPT

### Allow LAN to access internet
iptables -A OUTPUT -o $PrxPubVBR -s $PfsVmWanIP -d $PublicIP -j ACCEPT

### Proxmox Host as CLIENT
# Allow SSH - Set port for SSH
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p tcp --dport XX -j ACCEPT
# Allow DNS
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p udp --dport 53 -j ACCEPT
# Allow Whois
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p tcp --dport 43 -j ACCEPT
# Allow HTTP/HTTPS
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p tcp --dport 443 -j ACCEPT

### Proxmox Host as SERVER
# Allow SSH - Set port for SSH
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p tcp --sport XX -j ACCEPT
# Allow PROXMOX WebUI - Set port for WebUI
iptables -A OUTPUT -o $PrxPubVBR -s $PublicIP -p tcp --sport XX -j ACCEPT

### FORWARD RULES
# ----------------

# Allow request forwarding to PFSense WAN interface
iptables -A FORWARD -i $PrxPubVBR -d $PfsVmWanIP -o $PrxVmWanVBR -p tcp -j ACCEPT
iptables -A FORWARD -i $PrxPubVBR -d $PfsVmWanIP -o $PrxVmWanVBR -p udp -j ACCEPT

# Allow request forwarding from LAN
iptables -A FORWARD -i $PrxVmWanVBR -s $VmWanNET -j ACCEPT

### MASQUERADE MANDATORY
# Allow WAN network (PFSense) to use vmbr0 public adress to go out
iptables -t nat -A POSTROUTING -s $VmWanNET -o $PrxPubVBR -j MASQUERADE

### Redirect (NAT) traffic from internet
# All tcp to PFSense WAN except XX, XX (SSH and WebUI ports)
iptables -A PREROUTING -t nat -i $PrxPubVBR -p tcp --match multiport ! --dports XX,XX -j DNAT --to $PfsVmWanIP
# All udp to PFSense WAN
iptables -A PREROUTING -t nat -i $PrxPubVBR -p udp -j DNAT --to $PfsVmWanIP

	# ----------------------
	# RULES FOR PrxVmWanVBR
	# ----------------------

### INPUT RULES
# ---------------

# SSH (Server) - Set your port
iptables -A TCP -i $PrxVmWanVBR -d $ProxVmWanIP -p tcp --dport XXXX -j ACCEPT

# Proxmox WebUI (Server) - Set your port
iptables -A TCP -i $PrxVmWanVBR -d $ProxVmWanIP -p tcp --dport XXXX -j ACCEPT

### OUTPUT RULES
# ---------------

# Allow SSH server - Set your port
iptables -A OUTPUT -o $PrxVmWanVBR -s $ProxVmWanIP -p tcp --sport XXXX -j ACCEPT
# Allow PROXMOX WebUI on Public Interface from Internet - Set your port
iptables -A OUTPUT -o $PrxVmWanVBR -s $ProxVmWanIP -p tcp --sport XXXX -j ACCEPT

	# -----------------------
	# RULES FOR PrxVmPrivVBR
	# -----------------------

# NO RULES => All blocked !!!
