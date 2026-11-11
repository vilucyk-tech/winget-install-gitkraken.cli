# MikroTik CHR virtual router on Windows (Hyper-V)

## Requirements

- Windows 10/11 Pro/Enterprise or Windows Server with Hyper-V enabled:
  ```powershell
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All   # reboot afterwards
  ```
- PowerShell **as Administrator**.

## Create the VM

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\chr\New-ChrVm.ps1                      # latest stable v7
.\chr\New-ChrVm.ps1 -Version 7.16.2      # specific version
```

Topology:

```
 Internet ── Windows NAT ("Default Switch") ── ether1 [CHR] ether2 ── "CHR-LAN" (private) ── lab VMs
                                              DHCP client        192.168.88.1/24, DHCP server, NAT
```

Console: `vmconnect.exe localhost CHR`. Login `admin`, empty password; set a new one when prompted.

## Base router config (paste into the CHR console)

```routeros
/system identity set name=CHR-LAB
# ether1 already has a DHCP client on a fresh CHR (client1, bound) - nothing to add for WAN
/ip address add address=192.168.88.1/24 interface=ether2
/ip pool add name=lan-pool ranges=192.168.88.10-192.168.88.200
/ip dhcp-server add name=lan-dhcp interface=ether2 address-pool=lan-pool disabled=no
/ip dhcp-server network add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=192.168.88.1
/ip dns set allow-remote-requests=yes
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="LAN -> WAN"

# Minimal input protection on WAN
/ip firewall filter
add chain=input connection-state=established,related action=accept
add chain=input in-interface=ether1 protocol=icmp action=accept
add chain=input in-interface=ether1 action=drop comment="drop all other input from WAN"
```

This config was validated on CHR 7.25.1 (QEMU): an Alpine client on ether2 got
`192.168.88.200/24` via DHCP, reached the WAN side through masquerade, and SSH from
the WAN side was dropped by the input filter.

Check:

```routeros
/ip address print
/ip dhcp-client print
/ping 1.1.1.1 count=3
```

Any VM connected to the `CHR-LAN` switch then gets an address from 192.168.88.0/24 and reaches the internet through the CHR.

## Management from Windows

`CHR-LAN` is a *private* switch, so the host cannot reach it. Two options:
- Winbox/SSH to the ether1 address shown by `/ip dhcp-client print` (temporarily allow it in the input filter), or
- change `CHR-LAN` to an *Internal* switch: `Set-VMSwitch CHR-LAN -SwitchType Internal`, then give the host vEthernet adapter an address in 192.168.88.0/24.

## Limitations

- **License:** with no license, CHR runs as *free*, limited to 1 Mbit/s per interface. A 60-day trial of p1/p10/unlimited is available after registering with a mikrotik.com account (`/system license renew`).
- **PTP / 802.1AS:** CHR has no hardware timestamping, so `/system ptp` (gPTP, G.8275.1) is a function of physical CRS/CCR switches and cannot be tested meaningfully on CHR.
- Hyper-V **Default Switch** changes its subnet after a host reboot; use an External switch (`-WanSwitch <name>`) if you need a stable WAN address.

## Remove

```powershell
Stop-VM CHR -TurnOff; Remove-VM CHR -Force
Remove-Item "$env:PUBLIC\Documents\Hyper-V\CHR\CHR" -Recurse -Force
Remove-VMSwitch CHR-LAN -Force
```
