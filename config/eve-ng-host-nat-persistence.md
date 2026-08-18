# EVE-NG Host NAT Persistence on Google Cloud

This guide documents how to make the EVE-NG host NAT configuration persistent across Google Cloud VM reboots.

## Purpose

The EVE-NG host uses `pnet1` as the internal NAT-side interface for the pfSense WAN network.

- EVE host NAT interface: `172.16.1.1/24`
- pfSense WAN: `172.16.1.2/24`
- NAT subnet: `172.16.1.0/24`
- Internet-facing host interface: `pnet0`

The configuration below restores the `pnet1` IP address, enables IPv4 forwarding, and reapplies the required `iptables` NAT/forwarding rules after each reboot.

> **Security note:** These commands do not contain passwords, API keys, tokens, private certificates, usernames, or public IP addresses. The `172.16.1.0/24` addresses are RFC1918 private addresses and are safe to document publicly. Before publishing any future logs or screenshots, still check for credentials, public IPs, email addresses, project IDs, SSH keys, or other identifying information.

## 1. Make IPv4 forwarding persistent

Create a sysctl configuration file:

```bash
sudo nano /etc/sysctl.d/99-eve-nat.conf
```

Add:

```text
net.ipv4.ip_forward=1
```

Apply the setting:

```bash
sudo sysctl --system
```

Verify:

```bash
sysctl net.ipv4.ip_forward
```

Expected result:

```text
net.ipv4.ip_forward = 1
```

## 2. Create the NAT startup script

Create the script:

```bash
sudo nano /usr/local/sbin/eve-nat-start.sh
```

Add:

```bash
#!/bin/bash
set -e

# Configure the EVE-NG NAT-side interface
ip addr replace 172.16.1.1/24 dev pnet1
ip link set pnet1 up

# NAT EVE-NG WAN traffic through the Google Cloud interface
iptables -t nat -C POSTROUTING -s 172.16.1.0/24 -o pnet0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o pnet0 -j MASQUERADE

# Allow traffic from the EVE-NG NAT network toward the Internet
iptables -C FORWARD -i pnet1 -o pnet0 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i pnet1 -o pnet0 -j ACCEPT

# Allow established and related return traffic back into EVE-NG
iptables -C FORWARD -i pnet0 -o pnet1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i pnet0 -o pnet1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

Make the script executable:

```bash
sudo chmod +x /usr/local/sbin/eve-nat-start.sh
```

## 3. Test the script manually

Run:

```bash
sudo /usr/local/sbin/eve-nat-start.sh
```

Check the NAT-side interface:

```bash
ip addr show pnet1
```

You should see:

```text
172.16.1.1/24
```

Check the NAT rule:

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

You should see a `MASQUERADE` rule for:

```text
172.16.1.0/24
```

## 4. Create a systemd service

Create the service file:

```bash
sudo nano /etc/systemd/system/eve-nat.service
```

Add:

```ini
[Unit]
Description=EVE-NG pnet1 NAT configuration
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/eve-nat-start.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Reload systemd and enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable eve-nat.service
sudo systemctl start eve-nat.service
```

Verify:

```bash
sudo systemctl status eve-nat.service --no-pager
```

Expected status:

```text
Active: active (exited)
```

## 5. Reboot test

Reboot the Google Cloud VM:

```bash
sudo reboot
```

After reconnecting, verify the configuration:

```bash
ip addr show pnet1
sysctl net.ipv4.ip_forward
sudo iptables -t nat -L POSTROUTING -n -v
sudo systemctl status eve-nat.service --no-pager
```

The following should still be present after reboot:

- `pnet1` has `172.16.1.1/24`
- `net.ipv4.ip_forward = 1`
- `MASQUERADE` exists for `172.16.1.0/24`
- `eve-nat.service` shows `active (exited)`

## 6. pfSense connectivity test

After the host configuration has survived a reboot, start pfSense and confirm that the WAN interface can access the Internet.

The expected WAN configuration is:

```text
WAN IP: 172.16.1.2/24
Gateway: 172.16.1.1
```

At this point the Google Cloud/EVE-NG host NAT configuration can be considered persistent and the project can proceed to the pfSense-to-Open-vSwitch 802.1Q trunk and final VLAN addressing.
