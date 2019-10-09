Install the wpa_supplicant package
 linux-firmware 
 
 ip link set wlan0 up
 wpa_passphrase my_essid my_passphrase > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
/etc/wpa_supplicant/wpa_supplicant-wlan0.conf

Install the dhcpcd package
ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant /usr/lib/dhcpcd/dhcpcd-hooks/
dhcpcd.service
