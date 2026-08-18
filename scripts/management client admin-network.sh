#!/bin/bash
set -e

CONNECTION="netplan-ens3"

nmcli connection modify "$CONNECTION" ipv4.method manual
nmcli connection modify "$CONNECTION" ipv4.addresses 10.50.50.10/24
nmcli connection modify "$CONNECTION" ipv4.gateway 10.50.50.1
nmcli connection modify "$CONNECTION" ipv4.dns "8.8.8.8 1.1.1.1"
nmcli connection modify "$CONNECTION" ipv6.method disabled

nmcli connection down "$CONNECTION"
nmcli connection up "$CONNECTION"

echo "Admin network configuration applied."
ip addr show ens3
ip route
