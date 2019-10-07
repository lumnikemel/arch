#!/bin/bash

# This script will create a functional running Arch installation from a booted Arch-ISO.
# This creates a UEFI install with systemd-boot.
# To use this script simply run the following command from the Arch-ISO:
# wget -O - https://raw.githubusercontent.com/lumnikemel/arch/master/install.sh | sh
# Shortened link is: https://is.gd/ArchInstall. Note that the A and I must be capitalized, or it won't be the right link.


echo "IP Address is:"
ip a | grep "inet " | grep -v "127.0.0.1" | cut -d " " -f 6 | cut -d '/' -f 1

sgdisk --clear \
  --new 1::+100M --typecode=1:ef00 --change-name=1:'EFI' \
  --new 2::-0 --typecode=2:8300 --change-name=2:'System' \
  /dev/sda
mkfs.vfat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2

# you can find your closest server from: https://www.archlinux.org/mirrorlist/all/
echo 'Server = http://il.us.mirror.archlinux-br.org/$repo/os/$arch' > /etc/pacman.d/mirrorlist
mount /dev/sda2 /mnt

# Mount the EFI boot partition to /boot. ALT: /boot/efi is a separate boot loader is needed.
# Not sure if ZFS needs this.
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

pacman -Syy

# would recommend to use linux-lts kernel if you are running a server environment, otherwise just use "linux"
pacstrap /mnt base base-devel intel-ucode openssh ntp
genfstab -U /mnt >> /mnt/etc/fstab

cat << EOF > /mnt/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCaRMjE3Ss87DyJTtK+eW7TxyyXYOGznB2cGrIaDTW6Uy9MK5CYgA+QZG3kXYptB+x/PyrwgDBxFkTUDHNnZZKWlVUPNdwUQSAiHWBGQ6in26boWBpISEqyNQa32ghkNaPHcRvj5g2yxAdkN4YlnNfUUySp/gw4dxe4wqS+IgSAjuWbIfRUFXBqqSHt6wK9WTykDoEjLm/O95TH5Zz7kMuhCofvXHMjGs1pRjC1xnZbG7npbQVAydr9UMdTLpNVzVW+WkWQCeBIysAE3WMJB8oajn4ZO50Rb/22Hw3mQpJj9cQrnDGWvp+1SdqNZTJ9Yu4591bSbJinjoODvxzHMJtl1U18vX8s1MGdNelAodYdJpd0uU6ZhW35yKn2II9KK3IU7ZUirzU/esn8rktMLWywvrvoLBXK6LkSMLBA7G0xDWJvnF5TtPD2U0Q1dbt3758rjWwEOPci/VO1MbFWNMP4aa7YF+8NxUHUtuLfiIsV4x9HVBG9EwP4gj5De3yUYAc= Persona@Asmodeus
EOF

cat << EOF > /mnt/chroot.sh
#!/bin/bash

# run these following essential service by default
systemctl enable sshd.service
systemctl enable dhcpcd.service
systemctl enable ntpd.service

echo arch > /etc/hostname

# Add matching entries to hosts(5):
echo "127.0.0.1	localhost" >> /etc/hosts
echo "::1		localhost" >> /etc/hosts


# adding your normal user with additional wheel group so can sudo
useradd -m -G wheel -s /bin/bash arch

# adding public key both to root and user for ssh key access
mkdir -m 700 /home/arch/.ssh
mkdir -m 700 /root/.ssh
cp /authorized_keys /home/arch/.ssh
cp /authorized_keys /root/.ssh
chown -R arch:arch /home/arch/.ssh

#Set the time zone:
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

#Run hwclock(8) to generate /etc/adjtime:
hwclock --systohc

# adjust your name servers here if you don't want to use google
echo 'name_servers="10.0.0.1"' >> /etc/resolvconf.conf




echo en_US.UTF-8 UTF-8 > /etc/locale.gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
locale-gen

# because we are using ssh keys, make sudo not ask for passwords
echo 'root ALL=(ALL) ALL' > /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# I like to use nano :)
echo -e 'EDITOR=nano' > /etc/environment

# auto-complete these essential commands
echo complete -cf sudo >> /etc/bash.bashrc
echo complete -cf man >> /etc/bash.bashrc

# Optimization: Standardize System: Change network interface to generic "eth0"-like names.
ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

# Optimization: Minimize Writes: Store ext4 FS journal in RAM.
echo "Storage=volatile" >> /etc/systemd/journald.conf
echo "SystemMaxUse=16M" >> /etc/systemd/journald.conf

# Optimization: Minimize Writes: Removes "access time" logging on files.
sed -i 's/relatime/noatime/g' /etc/fstab

e2label /dev/sda2 System

# Install and set up bootloader.
bootctl --path=/boot install
touch /boot/loader/entries/arch.conf
echo "title   Arch Linux" >> /boot/loader/entries/arch.conf
echo "linux   /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "initrd  /intel-ucode.img" >> /boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "options root=LABEL=System rw iommu=on" >> /boot/loader/entries/arch.conf

# Initramfs
# Creating a new initramfs is usually not required, because mkinitcpio was run on installation of the linux package with pacstrap.
# For special configurations, modify the mkinitcpio.conf(5) file and recreate the initramfs image:
mkinitcpio -p linux

# Optmize: Power Actions
# I like to use laptops as servers, so having the default action to suspend on lid-close doesn't work out so well.
# Set systemd to ignore the Lid Switch when connected to External Power.
#HandleLidSwitchExternalPower=suspend
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g' /etc/systemd/logind.conf

exit
EOF
chmod +x /mnt/chroot.sh

arch-chroot /mnt /chroot.sh

rm /mnt/chroot.sh
rm /mnt/authorized_keys

umount -R /mnt
systemctl reboot
