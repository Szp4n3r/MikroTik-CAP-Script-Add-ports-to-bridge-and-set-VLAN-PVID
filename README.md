## Script for MikroTik CAP devices controlled by CAPsMAN with "wifi-qcom-ac" drivers to add ports to bridge and set PVID.

### Scenario:
cAP broadcasts two (or more) networks, separated into **TWO VLANs**!</br>
One on physical wifi interfaces (as a corporate network) with VLAN 100.</br>
The second (and subsequent) on virtual dynamic wifi interfaces (as a guest network) with vlan 200.</br>

### Problem:
Any configuration changes or loss of connection to CAPsMAN will result in the addition of new virtual interfaces (wifi3, wifi4, etc.) that will not be in the bridge = they will not be tagged = wifi will not working..

### Solution:
A script checks whether the “wifi..” interface is in the bridge (excluding wifi-2ghz and wifi-5ghz), and if not, adds it and assigns a PVID. Additionally, it removes all non-existent interfaces from the bridge. 

## SCRIPT:
The script should be run periodically using a scheduler.
```
# WiFi bridge auto-fix - compatibility with RouterOS 7.20
# BRIDGE NAME
:local bridgeName "bridge-local"
# VLAN FOR GUEST NETWORK
:local targetPVID 200
# BYPASS PORTS LIST (STATIC CONFIGURATION OF VLAN)
:local staticPorts {"ether1";"ether2";"wifi-2ghz";"wifi-5ghz"}

# 1) Review bridge ports and remove invalid ones (but DO NOT touch staticPorts)
:local bridgePorts [/interface bridge port find where bridge=$bridgeName]
:foreach portID in=$bridgePorts do={
    :local ifaceName [/interface bridge port get $portID interface]

    # check membership in staticPorts
    :local isStatic false
    :foreach p in=$staticPorts do={
        :if ($p = $ifaceName) do={ :set isStatic true }
    }

    # if it is a "holy" port - we do NOTHING
    :if ($isStatic = false) do={

        # check if an interface with this name exists at all
        :local foundCount [:len [/interface find where name=$ifaceName]]
        :if ($foundCount = 0) do={
            :log warning ("[wifi_bridge_fix] Removing bridge port (missing iface): " . $ifaceName)
            /interface bridge port remove $portID
        } else={
            # if it exists, check if it is disabled or not-running
            :local disabled [/interface get $ifaceName disabled]
            :local running [/interface get $ifaceName running]
            :if ($disabled = true || $running = false) do={
                :log warning ("[wifi_bridge_fix] Removing bridge port (inactive): " . $ifaceName)
                /interface bridge port remove $portID
            }
        }
    }
}

# 2) Go through all interfaces starting with "wifi" and add to bridge / set PVID (but DO NOT touch staticPorts)
:local wifiIfs [/interface find where name~"^wifi"]
:foreach iid in=$wifiIfs do={
    :local ifaceName [/interface get $iid name]

    # skip bypass ports
    :local isStatic false
    :foreach p in=$staticPorts do={
        :if ($p = $ifaceName) do={ :set isStatic true }
    }
    :if ($isStatic = true) do={
        :log warning ("[wifi_bridge_fix] Skip static wifi: " . $ifaceName)
    } else={

        # is it already a port in bridge?
        :local existing [/interface bridge port find where bridge=$bridgeName and interface=$ifaceName]
        :if ([:len $existing] = 0) do={
            :log warning ("[wifi_bridge_fix] Adding to bridge: " . $ifaceName . " PVID=" . $targetPVID)
            /interface bridge port add bridge=$bridgeName interface=$ifaceName pvid=$targetPVID
        } else={
            :local currentPVID [/interface bridge port get $existing pvid]
            :if ($currentPVID != $targetPVID) do={
                :log warning ("[wifi_bridge_fix] Fixing PVID for " . $ifaceName . " -> " . $targetPVID)
                /interface bridge port set $existing pvid=$targetPVID
            }
        }
    }
}
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
    disabled=no name=wifi-2ghz
set [ find default-name=wifi2 ] configuration.manager=capsman .mode=ap \
    disabled=no name=wifi-5ghz
/interface bridge port
add bridge=bridge-local interface=ether1
add bridge=bridge-local interface=ether2
add bridge=bridge-local interface=wifi-2ghz pvid=100
add bridge=bridge-local interface=wifi-5ghz pvid=100
/interface bridge vlan
add bridge=bridge-local tagged=ether1,ether2 vlan-ids=100
add bridge=bridge-local tagged=ether1,ether2 vlan-ids=200
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
add interface=bridge-local name=vlan100-wifi-team vlan-id=100
add interface=bridge-local name=vlan200-wifi-guest vlan-id=200
/interface wifi datapath
add bridge=bridge-local client-isolation=yes disabled=no name=\
    datapath-vlan200-wifi-guest vlan-id=none
add bridge=bridge-local disabled=no name=datapath-vlan100-wifi-team \
    vlan-id=100
/interface wifi channel
[... add your wifi channel configuration ...]
/interface wifi security
[... add your wifi security configuration ...]
/interface wifi configuration
[... add your wifi configuration with Channel,Security,Datapath templates ...]
/interface bridge vlan
add bridge=bridge-local tagged=\
    bridge-local,ether5-cap vlan-ids=100
add bridge=bridge-local tagged=\
    bridge-local,ether5-cap vlan-ids=200
/interface wifi capsman
set enabled=yes interfaces=[your-interface-for-mgmt-caps]
/interface wifi provisioning
[... add your provisioning template with action "create enable dynamic" ...]

[... remember about your IP,Firewall,etc configuration of Router :) ...]
```
