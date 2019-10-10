#!/bin/bash


sudo pacman -Syu --noconfirm usbutils
# Ensure USB printer is seen
lsusb
# Printer shows up as:
  # Bus 001 Device 010: ID 413c:564f Dell Computer Corp.
    

# https://wiki.archlinux.org/index.php/CUPS
sudo pacman -Syu --noconfirm cups

sudo systemctl enable org.cups.cupsd.service
sudo systemctl start org.cups.cupsd.service

# https://wiki.archlinux.org/index.php/CUPS/Printer_sharing
sudo pacman -Syu --noconfirm samba

cat << EOF > /etc/samba/smb.conf
[global]
...
printing = CUPS
...

[printers]
    comment = All Printers
    path = /var/spool/samba
    browseable = yes
    # to allow user 'guest account' to print.
    guest ok = yes
    writable = no
    printable = yes
    create mode = 0700
    write list = root @adm @wheel arch
    # valid users = root @adm @wheel yourusername # used if not allowing guest access
EOF

sudo systemctl enable smb.service
sudo systemctl start smb.service
sudo systemctl enable nmb.service
sudo systemctl start nmb.service



sudo systemctl restart smb.service
sudo systemctl restart nmb.service
