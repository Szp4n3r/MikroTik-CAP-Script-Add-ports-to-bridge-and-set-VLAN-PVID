# WiFi bridge auto-fix ports and vlans - compatibility with RouterOS 7.20.4
## DEFINE
## Dodaj vlany w odpowiedniej kolejnosci (cAPSMAN dodaje je zawsze identycznie)
:local pvidList {31;30;70;31;30;70}
## Podaj liczbe portow w bridge (2xEther + 2xWlan + ?xWifi)
:local requiredPortCount 10

## CHECK UNKOWN
#:log warning "Rozpoczynam sprawdzanie"
#:local unkownPort [/interface/bridge/port find where interface~"^\\*"]
#:if ([:len $unkownPort] = 0) do={
#    :log warning "Koniec - nie znaleziono UNKOWN portow"
##    /quit
#}

## CHECK COUNT
:local totalPorts [/interface/bridge/port find]
:local totalCount [:len $totalPorts]
:if ($totalCount = $requiredPortCount) do={
    :log warning "Koniec - liczba portow w bridge jest poprawna"
    /quit
}

## DELETE UNKOWN
:foreach i in=[/interface/bridge/port find where interface~"^\\*"] do={
    /interface/bridge/port remove $i
    :log info "-> Usuwam $i"
}
:log info "-> Porty UNKOWN usuniete"

## DELETE WIFI
:foreach i in=[/interface/bridge/port find where interface~"^wifi"] do={
    /interface/bridge/port remove $i
    :log info ("-> Usuwam wifi " . $i)
}
:log info "-> Porty WIFI usuniete"

## ADD
:local idx 0
:foreach i in=[/interface find where name~"^wifi"] do={
    :local ifaceName [/interface get $i name]
    :local pvid ($pvidList->$idx)
    /interface/bridge/port add bridge=bridge-local interface=$ifaceName pvid=$pvid
    :log info ("-> Dodano " . $ifaceName . " do bridge-local z PVID=" . $pvid)
    :set idx ($idx + 1)
}
:log warning "Koniec - porty usuniete i dodane ponownie"
