## Script for MikroTik cAP devices controlled by CAPsMAN with "wifi-qcom-ac" drivers to add ports to bridge and set PVID.

### Scenario:
The cAP advertises several networks, divided into different VLANs (in this example = 8 (4 x 2.4GHz & 4 x 5GHz)).
Two WiFi networks are created on the primary WiFi interfaces – the ones that "don't disappear".<br>
The remaining WiFi networks are created as virtual interfaces.

### Wi-Fi diagram - mirroring the Provisioning tab on CAPsMAN:
```
cAP
├── wlan-2ghz ( band 2,4GHz - wifi HotSpot1 - vlan 10 )
│   ├── wifi1 ( band 2,4GHz - wifi HotSpot2 - vlan 20 )
│   ├── wifi2 ( band 2,4GHz - wifi HotSpot3 - vlan 30 )
│   └── wifi3 ( band 2,4GHz - wifi HotSpot4 - vlan 40 )
└── wlan-5ghz ( band 5GHz - wifi HotSpot1 - vlan 10 )
    ├── wifi4 ( band 5GHz - wifi HotSpot2 - vlan 20 )
    ├── wifi5 ( band 5GHz - wifi HotSpot3 - vlan 30 )
    └── wifi6 ( band 5GHz - wifi HotSpot4 - vlan 40 )
```

### Problem:
Any configuration change or loss of connection to CAPsMAN will result in the addition of new virtual interfaces (wifi7, wifi8, etc.) that will not be in the bridge = they will not be marked = Wi-Fi will not work properly.

### Solution:
The script checks whether the number of ports in the bride is appropriate and in case of an error, removes and adds all "wifi" ports, re-assigning the appropriate PVID.

### Important - necessary to do on cAP/in script:
1. The built-in Wi-Fi interfaces on the cAP must be named something other than "wifi.." - I recommend "wlan-2ghz" and "wlan-5ghz".
2. Assign a permanent VLAN (PVID in bridge/ports) for "wlan-2ghz" and "wlan-5ghz" ports (in our case, VLAN ID = 10).
3. In the script, edit the number of interfaces that should be in the bridge - in my case, 10 (4 fixed (ether1,ether2,wlan-2ghz,wlan-5ghz) and 6 dynamic (wifi1,wlan2,..)).
4. In the script, edit the VLAN sequence according to your specifications - in my case: {20,30,40,20,30,40} (the order is as shown in the diagram).

## SCRIPT:
The script should be run periodically using a scheduler.
```
## DEFINE
## Add vlans in the correct order (cAPSMAN always adds them identically)
:local pvidList {20,30,40,20,30,40}
## Enter the number of ports in the bridge (2xEther + 2xWlan + ?xWifi)
:local requiredPortCount 10

## CHECK UNKOWN
#:log warning "Starting to check"
#:local unkownPort [/interface/bridge/port find where interface~"^\\*"]
#:if ([:len $unkownPort] = 0) do={
#    :log warning "Finish - no UNKNOWN ports found"
##    /quit
#}

## CHECK COUNT
:log warning "Starting to check"
:local totalPorts [/interface/bridge/port find]
:local totalCount [:len $totalPorts]
:if ($totalCount = $requiredPortCount) do={
    :log warning "Finish - the number of ports in the bridge is correct"
    /quit
}

## DELETE UNKOWN
:foreach i in=[/interface/bridge/port find where interface~"^\\*"] do={
    /interface/bridge/port remove $i
    :log info "-> Deleting $i"
}
:log info "-> UNKOWN ports removed"

## DELETE WIFI
:foreach i in=[/interface/bridge/port find where interface~"^wifi"] do={
    /interface/bridge/port remove $i
    :log info ("-> Deleting wifi " . $i)
}
:log info "-> WIFI ports removed"

## ADD
:local idx 0
:foreach i in=[/interface find where name~"^wifi"] do={
    :local ifaceName [/interface get $i name]
    :local pvid ($pvidList->$idx)
    /interface/bridge/port add bridge=bridge-local interface=$ifaceName pvid=$pvid
    :log info ("-> Dodano " . $ifaceName . " do bridge-local z PVID=" . $pvid)
    :set idx ($idx + 1)
}
:log warning "Finish - ports removed and added again"
```
</br>

## MY SETUP
Configuration created based on instructions:</br>
https://help.mikrotik.com/docs/spaces/ROS/pages/224559120/WiFi#WiFi-CAPsMAN%3A

### cAP controlled by external CAPsMAN:
```
/interface bridge
add name=bridge-local vlan-filtering=yes
/interface wifi
set [ find default-name=wifi1 ] configuration.manager=capsman .mode=ap \
    disabled=no name=wlan-2ghz
set [ find default-name=wifi2 ] configuration.manager=capsman .mode=ap \
    disabled=no name=wlan-5ghz
/interface bridge port
add bridge=bridge-local interface=ether1
add bridge=bridge-local interface=ether2
add bridge=bridge-local interface=wlan-2ghz pvid=10
add bridge=bridge-local interface=wlan-5ghz pvid=10
/interface bridge vlan
add bridge=bridge-local tagged=ether1,ether2 vlan-ids=10
add bridge=bridge-local tagged=ether1,ether2 vlan-ids=20
add bridge=bridge-local tagged=ether1,ether2 vlan-ids=30
add bridge=bridge-local tagged=ether1,ether2 vlan-ids=40
/interface wifi cap
set caps-man-addresses=[your-capsman-ip] discovery-interfaces=none enabled=yes

[... remember about your IP,Firewall,etc configuration of AP :) ...]
```
### MikroTik as CAPsMAN:
```
/interface bridge
add name=bridge-local vlan-filtering=yes
/interface ethernet
set [ find default-name=ether5 ] name=ether5-cap
/interface bridge port
add bridge=bridge-local interface=ether5-cap
/interface vlan
add interface=bridge-local name=vlan10 vlan-id=10
add interface=bridge-local name=vlan20 vlan-id=20
add interface=bridge-local name=vlan20 vlan-id=30
add interface=bridge-local name=vlan20 vlan-id=40
/interface wifi datapath
add bridge=bridge-local client-isolation=yes disabled=no name=\
    datapath-vlan10 vlan-id=none
add bridge=bridge-local client-isolation=yes disabled=no name=\
    datapath-vlan20 vlan-id=none
add bridge=bridge-local client-isolation=yes disabled=no name=\
    datapath-vlan30 vlan-id=none
add bridge=bridge-local client-isolation=yes disabled=no name=\
    datapath-vlan40 vlan-id=none
/interface wifi channel
[... add your wifi channel configuration ...]
/interface wifi security
[... add your wifi security configuration ...]
/interface wifi configuration
[... add your wifi configuration with Channel,Security,Datapath templates ...]
/interface bridge vlan
add bridge=bridge-local tagged=\
    bridge-local,ether5-cap vlan-ids=10
add bridge=bridge-local tagged=\
    bridge-local,ether5-cap vlan-ids=20
add bridge=bridge-local tagged=\
    bridge-local,ether5-cap vlan-ids=30
add bridge=bridge-local tagged=\
    bridge-local,ether5-cap vlan-ids=40
/interface wifi capsman
set enabled=yes interfaces=[your-interface-for-mgmt-caps]
/interface wifi provisioning
[... add your provisioning template with action "create enable dynamic" ...]

[... remember about your IP,Firewall,etc configuration of Router :) ...]
```
