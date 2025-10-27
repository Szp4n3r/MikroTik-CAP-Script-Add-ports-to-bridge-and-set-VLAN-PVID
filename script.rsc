# WiFi bridge auto-fix - compatibility with RouterOS 7.20
# BRIDGE NAME
:local bridgeName "bridge-local"
# VLAN FOR GUEST NETWORK
:local targetPVID 100
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