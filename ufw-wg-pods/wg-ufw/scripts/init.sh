#!/bin/bash
# write output to logfile
exec > /etc/wireguard/config/init.log 2>&1

# add DNS entries for internet access
echo nameserver 8.8.8.8 > /etc/resolv.conf
echo nameserver 8.8.4.4 >> /etc/resolv.conf

# Test internet connectivity in pod by looping updating system
apt update && apt upgrade -y
while [ $? -ne 0 ] 
do
  echo ">>>>>>> Waiting for update and upgrade to complete" 
  sleep 0.3
  apt update && apt upgrade -y
done
echo "******* Update and upgrade to completed" 

# Install networking and firewall packages
echo ">>>>>>> Installing networking and firewall packages" 
apt install -y iproute2 && apt install -y iputils-ping && apt install -y iptables && apt install -y ufw
apt install -y wget && apt install -y vim && apt install -y cron
# setup upgrade SSH access, optional
#apt install -y openssh-server
#systemctl restart sshd
echo "******* Networking and firewall packages installed" 

# Clean up past Wireguard installs
rm -rf /etc/wireguard/wg0.*

# install Wireguard with some initial configs
. /etc/wireguard/config/wg-install.sh

# add intial UFW firewall rules and enable the UFW
echo ">>>>>>> Adding ufw rules"
# ufw rules default is deny all incoming and allow all outgoing and allow all routed traffic
echo ">>>>>>> INTERNAL interface RULES"
ufw deny from $wgcnet to $inip comment 'DENY customer and partner traffic to this node'
ufw allow to $inip port 5000 proto tcp comment 'Allow wireguard-ui in the DMZ'
ufw allow to $corpip port 5000 proto tcp comment 'Allow wireguard-ui internally'
# Wiregaurd UFW rules
echo ">>>>>>> Adding Wireguard UFW RULES"
echo ">>>>>>> Allow wireguard VPN to external IP address"
ufw allow from any to $exip port 51820 proto udp comment 'Allow wireguard externally'
# setup port forwarding
# sysctl NOT working in pod
#sysctl net.ipv4.ip_forward
#sysctl net.ipv6.conf.all.forwarding
echo ">>>>>>> SETUP port forwarding by editing /etc/ufw/sysctl.conf"
# edit /etc/ufw/sysconf to allow fowarding
sed -i 's/#net\/ipv4\/ip_forward=1/net\/ipv4\/ip_forward=1/g' /etc/ufw/sysctl.conf
sed -i 's/#net\/ipv6\/conf\/default\/forwarding=1/net\/ipv6\/conf\/default\/forwarding=1/g' /etc/ufw/sysctl.conf
sed -i 's/#net\/ipv6\/conf\/all\/forwarding=1/net\/ipv6\/conf\/all\/forwarding=1/g' /etc/ufw/sysctl.conf

# NAT postrouting after the rules are applied
echo ">>>>>>> SETUP NAT postrouting after the rules are applied by editing /etc/ufw/after.rules"
echo "*nat" >> /etc/ufw/after.rules 
echo ":POSTROUTING ACCEPT [0:0]" >> /etc/ufw/after.rules 
# Adding the rule: wireguard postrouting forwarding (flush (-F) first because ufw and iptables has some stale entry issues)
echo "-F POSTROUTING" >> /etc/ufw/after.rules
echo "-A POSTROUTING -s $wgnet -j MASQUERADE" >> /etc/ufw/after.rules
echo "COMMIT" >> /etc/ufw/after.rules

# Add UFW forwarding rules
echo ">>>>>>> allow forwarding/routing"
ufw default allow routed comment 'ALLOW default forwarding policy'
# Because default is ALLOW UFW rules need to be REJECT or DENY [REJECT sends connection refuse messages]
echo ">>>>>>> REJECT wireguard routed traffic for customers and partners on private networks"
ufw route reject in on $wgif to $SEdmznet from $wgcnet comment 'REJECT partner routed traffic to SE private DMZ subnet on all ports'
ufw route reject in on $wgif to $corpnet from $wgcnet comment 'REJECT partner routed traffic to corporate network on all ports'

######## Adding MORE secure with ALLOW rules where the default is REJECT

# Add UFW forwarding rules
echo ">>>>>>> REJECT forwarding/routing as default rule"
ufw default reject routed comment 'REJECT default forwarding policy'
# Because default is ALLOW UFW rules need to be REJECT or DENY [REJECT sends connection refuse messages]
echo ">>>>>>> ALLOW wireguard routed traffic for SE users"
ufw route allow in on $wgif to $SEdmznet from $wgSEnet comment 'ALLOW SE routed traffic to SE private DMZ subnet on all ports'
ufw route allow in on $wgif to $customerdmznet from $wgSEnet comment 'ALLOW SE routed traffic to SE private DMZ subnet on all ports'
ufw route allow in on $wgif to $corpnet from $wgSEnet comment 'ALLOW SE routed traffic to corporate network on all ports'
ufw route allow in on $wgif to any from $wgSEnet comment 'ALLOW internet for SE users'
echo "******* ALLOW wireguard routed traffic for customers and partners on private networks"
ufw route allow in on $wgif to $customerdmznet from $wgcnet comment 'Allow customer and partner access to partner DMZ network'
ufw route allow in on $wgif to any from $wgcnet comment 'ALLOW internet for customers users'
ufw enable
ufw status

# Wireguard-ui install and auto-restart when wg0.conf updated
# https://github.com/ngoduykhanh/wireguard-ui/tree/master 

echo ">>>>>>> CREATE wireguard auto-restart service scripts -> /etc/wireguard/wg0.sh"
cat << EOF > /etc/wireguard/wg0.sh
#!/bin/bash
echo "PROCESSING WG0 config changes"
echo "----------- REMOVE peer config, if any < "
echo "\$((diff /etc/wireguard/wg0.conf.bak /etc/wireguard/wg0.conf) | sed -n 's_^< PublicKey = \(.*\)_\1_p')" > /etc/wireguard/rPEERs.tmp
cat /etc/wireguard/rPEERs.tmp
while IFS= read -r line
do
  echo "------------- Removing PulicKey PEER: \$line"
  wg set wg0 peer "\$line" remove
done < "/etc/wireguard/rPEERs.tmp"
rm -rf /etc/wireguard/rPEERs.tmp

echo "+++++++++++ ADD peer config, if any > "
echo "\$((diff /etc/wireguard/wg0.conf.bak /etc/wireguard/wg0.conf) | sed -n 's_^> \(.*\)_\1_p')" > /etc/wireguard/aPEERs.tmp
cat /etc/wireguard/aPEERs.tmp
wg addconf wg0 /etc/wireguard/aPEERs.tmp
rm -rf /etc/wireguard/aPEERs.tmp
echo ">> CREATE NEW WG0 BACKUP > /etc/wireguard/wg0.conf.bak"
cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak
EOF
chmod +x /etc/wireguard/wg0.sh

# Create systemd service at /etc/systemd/system/wgui.service
echo ">>>>>>> CREATE wireguard auto-restart systemd service script link -> /etc/systemd/system/wgui.service"
echo "[Unit]" > /etc/systemd/system/wgui.service
echo "Description=Update WireGuard" >> /etc/systemd/system/wgui.service
echo "After=network.target" >> /etc/systemd/system/wgui.service
echo "" >> /etc/systemd/system/wgui.service
echo "[Service]" >> /etc/systemd/system/wgui.service
echo "Type=oneshot" >> /etc/systemd/system/wgui.service
echo "ExecStart=/etc/wireguard/wg0.sh" >> /etc/systemd/system/wgui.service
echo "" >> /etc/systemd/system/wgui.service
echo "[Install]" >> /etc/systemd/system/wgui.service
echo "RequiredBy=wgui.path" >> /etc/systemd/system/wgui.service

# Create systemd RequiredBy wgui.path for above at /etc/systemd/system/wgui.path
echo ">>>>>>> CREATE wireguard auto-restart systemd service path -> /etc/systemd/system/wgui.path"
echo "[Unit]" >> /etc/systemd/system/wgui.path
echo "Description=Watch /etc/wireguard/wg0.conf for changes" >> /etc/systemd/system/wgui.path
echo "" >> /etc/systemd/system/wgui.path
echo "[Path]" >> /etc/systemd/system/wgui.path
echo "PathModified=/etc/wireguard/wg0.conf" >> /etc/systemd/system/wgui.path
echo "" >> /etc/systemd/system/wgui.path
echo "[Install]" >> /etc/systemd/system/wgui.path
echo "WantedBy=multi-user.target" >> /etc/systemd/system/wgui.path

# Enable and start the wgui auto-config wg0 based on wg0.conf change
echo ">>>>>>> ENABLE and START WGUI and wireguard systemd service"
systemctl enable wgui.{path,service}
systemctl start wgui.{path,service}

# create cronjob for weekly/monthly server reset at 1:00
echo ">>>>>>> CREATE CRONJOB for weekly/monthly server reset at 1:00"
# write out current crontab to cronjobs file
crontab -l > cronjobs
# echo new cron into cron file
echo "00 01 * * 0  wg-quick down wg0 && wg-quick up wg0  # restart 1:00 every Sunday" >> cronjobs
echo "00 01 1 * *  wg-quick down wg0 && wg-quick up wg0  # restart 1:00 every 1st day of every month" >> cronjobs
# install new cron file
crontab cronjobs
# remove/clean up cron file
rm cronjobs

##################### Additional notes
# Manual WG restart and check - needed for the VPN server changed
#systemctl restart wg-quick@wg0.service
#systemctl status wg-quick@wg0.service

# Non-disruptive enabling/adding client
#wg addconf wg0 <(sed -n "/^# Update at:    2023/,/^32/p" /etc/wireguard/wg0.conf)
# diff manipulation to get new Peer to add. Can add multiple Peers in one go.
# diff wg0.conf.1 wg0.conf.0 | sed -n 's_^< \(.*\)_\1_p'
# # ID:           <peer-id-generated-by-wireguard-ui>
# # Name:         example-client
# # Email:
# # Created at:   2024-01-01 00:00:00.000000000 +0000 UTC
# # Update at:    2024-01-01 00:00:00.000000000 +0000 UTC
# [Peer]
# PublicKey = <base64-peer-public-key>
# PresharedKey = <base64-peer-preshared-key>
# AllowedIPs = 10.10.10.3/32

# Non-disruptive disabling/removal client
#wg set wg0 peer "$(sed -n "/^# Update at:/,\$p" /etc/wireguard/wg0.conf | grep -m 1 PublicKey | cut -d " " -f 3)" remove
# diff manipulation to get PublicKeys to remove. Will need to remove Peer 1 by 1
# diff wg0.conf.2 wg0.conf.0 | sed -n 's_^< PublicKey = \(.*\)_\1_p'
# <base64-public-key-of-peer-1>
# <base64-public-key-of-peer-2>
# Full WG restart
#wg-quick down wg0 && wg-quick up wg0

# END
exit
