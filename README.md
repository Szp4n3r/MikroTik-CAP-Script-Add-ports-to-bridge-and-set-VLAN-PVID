## Script for MikroTik CAP devices controlled by CAPsMAN with "wifi-qcom-ac" drivers to add ports to bridge and set PVID.

Scenariusz:
cAP rozgłasza dwie (lub więcej) sieci dzieląc je na DWA vlany!
Jedna na interfejsach fizycznych wifi (jako sieć firmowa) z vlan 100.
Druga (i kolejne) na wirtualnych dynamicznych interfejsach wifi (jako sieć dla gości) z vlan 200.

Problem:
Każda zmiana konfiguracji lub ultrata połączenia do CAPsMAN`a spowoduje dodanie nowych wirtualnych interfejsów (wifi3, wifi4, itd.) które nie bedą w bridge = nie będą tagowane.

Rozwiązanie:
Skrypt sprawdzający czy interfejs "wifi.." jest w bridge (z pominięciem wifi-2ghz i wifi-5ghz), jeżeli nie to go dodaje i przypisuje PVID. Dodatkowo usuwa wszystkie interfejsy nieistniejące z bridge. 

skrypt:

MY SETUP
Configuration created based on instructions:
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
set caps-man-addresses=[your-capsman-ip discovery-interfaces=none enabled=yes
[... remember about your IP,Firewall,etc configuration of AP :) ...]
```
### MikroTik as CAPsMAN:
```
/interface bridge
add name=bridge-local vlan-filtering=yes
/interface ethernet
set [ find default-name=ether5 ] name=ether5-cap
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
[... remember about your IP,Firewall,etc configuration of AP :) ...]
```
