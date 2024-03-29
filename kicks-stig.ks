# add in the kernel boot
# inst.ks=http://ansible.live/kicks-stig.ks

#
#CentOS 7 STIG Kickstart
#Oct 2019
# Adaptations by bzanaj
#
# Keyboard layouts
keyboard 'us'
#Accept EULA
eula --agreed
# Root password
rootpw Password1
# Use network installation
url --url="http://mirror.csclub.uwaterloo.ca/centos/7/os/x86_64/"
repo --name=epel --baseurl="https://dl.fedoraproject.org/pub/epel/7/x86_64/"
# System language
lang en_US
# Firewall configuration
firewall --service=ssh
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use graphical install
text
# SELinux configuration
selinux --enforcing
# Network information
network  --bootproto=dhcp --device=eth0 --hostname=server.example.com --activate
# System timezone
timezone America/Chicago
# System bootloader configuration
bootloader --location=mbr --boot-drive=sda
# Partition clearing information
clearpart --all --initlabel
#Disk Partition Info
part /boot --fstype=xfs --size=500
part pv.008002 --grow --size=1
volgroup vg_centos --pesize=4096 pv.008002
logvol / --fstype=xfs --name=lv_root --vgname=vg_centos --grow --size=1024 --maxsize=8000
logvol swap --name=lv_swap --vgname=vg_centos --grow --size=1024 --maxsize=1024
logvol /var --fstype=xfs --name=lv_var --vgname=vg_centos --grow --size=1024 --maxsize=2000
logvol /var/log --fstype=xfs --name=lv_varlog --vgname=vg_centos --grow --size=1024 --maxsize=2000
logvol /var/log/audit --fstype=xfs --name=lv_varlogaudit --vgname=vg_centos --grow --size=1024 --maxsize=2000
logvol /tmp --fstype=xfs --name=lv_tmp --vgname=vg_centos --grow --size=1024 --maxsize=2000
logvol /home --fstype=xfs --name=lv_home --vgname=vg_centos --grow --size=1024	--maxsize=2000 --fsoptions="nosuid"
logvol /REPO --fstype=xfs --name=lv_repo --vgname=vg_centos --grow --size=1024 --maxsize=50000
#Disable firstboot
firstboot --disable
#Reboot when complete
reboot --eject

%packages
@base
@core
@guest-agents
@hardware-monitoring
@input-methods
@security-tools
esc
kexec-tools
openscap
openscap-scanner
openssh-server
pam_pkcs11
scap-security-guide
scap-workbench
sssd
aide
-rsh-server
-telnet-server
-tftp-server
-vsftpd
-ypserv
-gnome-initial-setup
-initial-setup-gui
-initial-setup

%end

#Commented out for CentoOS
#%addon org_fedora_oscap 
#
#    content-type = scap-security-guide
#
#    profile = stig-rhel7-disa
#
#%end

%addon com_redhat_kdump --enable --reserve-mb=auto

%end

%post --log /root/post.log

#!/bin/bash

set -x

# Set Banner for GUI
touch /etc/dconf/db/local.d/01-banner-message
cat << EOF > /etc/dconf/db/local.d/01-banner-message
[org/gnome/login-screen]
banner-message-enable=true
banner-message-text="This is a banner message\n authorized use only"
disable-user-list=true
EOF

# Set Banner for SSH
touch /etc/issue
cat <<EOF > /etc/issue

----------------------------------------------------------------------------------------------------
Use of this or any other interest computer system constitutes consent to monitoring at all times
----------------------------------------------------------------------------------------------------
EOF

dconf update

echo "session required pam_lastlog.so showfailed" >> /etc/pam.d/postlogin-ac

echo "" >> /etc/ntp.conf
echo "# Section added per STIG" >> /etc/ntp.conf
echo "maxpoll 10" >> /etc/ntp.conf

# ==== configure sshd_config ====
sed -ie 's/.*StrictModes.*/StrictModes yes/' /etc/ssh/sshd_config
sed -ie 's/"PermitRootLogin/"permitrootlogin/' /etc/ssh/sshd_config # to replace commented section to avoid error
sed -ie 's/.*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -ie 's/.*IgnoreUserKnownHosts.*/IgnoreUserKnownHosts yes/' /etc/ssh/sshd_config
sed -ie 's/.*IgnoreRhosts.*/IgnoreRhosts yes/' /etc/ssh/sshd_config
sed -ie 's/ RhostsRSAAuthentication and HostbasedAuthentication/ rhostsRSAAuthentication and hostbasedAuthentication/' /etc/ssh/sshd_config # to replace commented section to avoid error
sed -ie 's/.*HostbasedAuthentication.*/HostbasedAuthentication no/' /etc/ssh/sshd_config
sed -ie 's/.*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -ie 's/.*KerberosAuthentication.*/KerberosAuthentication no/' /etc/ssh/sshd_config
sed -ie 's/.*GSSAPIAuthentication.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -ie 's/.*PrintLastLog.*/PrintLastLog yes/' /etc/ssh/sshd_config
sed -ie 's/.*PermitUserEnvironment.*/PermitUserEnvironment no/' /etc/ssh/sshd_config 
sed -ie 's/.*Compression.*/Compression no/' /etc/ssh/sshd_config
sed -ie 's/.*ClientAliveInterval.*/ClientAliveInterval 600/' /etc/ssh/sshd_config
sed -ie 's/.*ClientAliveCountMax.*/ClientAliveCountMax 0/' /etc/ssh/sshd_config
sed -i '/Banner.*/c Banner /etc/issue' /etc/ssh/sshd_config
sed -i '/#UsePrivilegeSeperation/c UsePrivilegeSeperation' /etc/ssh/sshd_config
echo Protocol 2 >> /etc/ssh/sshd_config
echo RhostsRSAAuthentication no >> /etc/ssh/sshd_config

# Disable account identifiers after the password expires 
sed -ie 's/.*INACTIVE.*/INACTIVE=0/' /etc/default/useradd 

# Configure the operating system to terminate all network connections associated with a communications
# session at the end of the session or after a period of inactivity
cat << EOF >> /etc/profile

# ====== STIG Settings ======
TMOUT=600
EOF

# Configure the operating system to limit the number of concurrent sessions to "10" for all accounts and/or account types
sed -i '1s/^/* hard maxlogins 10\n/' /etc/security/limits.conf

# ==== configure yum.conf ====
cat << EOF >> /etc/yum.conf

# ====== STIG Settings ======
# Configure the operating system to verify the signature of local packages prior to install
localpkg_gpgcheck=1
# Configure the operating system to verify the repository metadata
# be sure to import epel key before installing it
repo_gpgcheck=1
# Configure the operating system to remove all software components after updated versions have been installed
clean_requirements_on_remove=1
EOF


# ==== configure login.defs ====
sed -ie 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS\t60/' /etc/login.defs
sed -ie 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS\t1/' /etc/login.defs
sed -ie 's/ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs
echo "FAIL_DELAY 4" >> /etc/logins.def

sed -ie 's/crypt_style.*/crypt_style = sha512/' /etc/libuser.conf

echo "password   required     pam_pwquality.so retry=3" >> /etc/pam.d/passwd

# Disable Mounting of cramfs, freevxfs, jffs2, hfs, hfsplus, squashfs, udf Filesystems  
touch /etc/modprobe.d/STIG.conf
/bin/cat << EOF > /etc/modprobe.d/STIG.conf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install usb-storage /bin/true
EOF

# Disable autofs
#systemctl disable autofs

# Disable Bluetooth
echo -e "install net-pf-31 /bin/false" >> /etc/modprobe.d/bluetooth.conf
echo -e "install bluetooth /bin/false" >> /etc/modprobe.d/bluetooth.conf

# Optional Disable IPv6
#echo -e "options ipv6 disable=1" >> /etc/modprobe.d/ipv6.conf

# Set Permissions and User/Group Owner on /etc/grub.conf 
chown root:root /boot/grub2/grub.cfg
chmod og-rwx /boot/grub2/grub.cfg

# Set Sticky Bit on All World-Writable Directories 
df --local -P | awk {'if (NR!=1) print $6'} | -exec -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null | -exec chmod a+t '{}' + 2>/dev/null

# If the cron.allow file exists it must be owned and group-owned by root
if [ -f "/etc/cron.allow" ]
then
	chown root /etc/cron.allow
	chgrp root /etc/cron.allow
fi

# ==== configure auditd_config ====
sed -i 's/\<space_left_action.*/space_left_action = email/' /etc/audit/auditd.conf

# If kernel core dumps are not required, disable the "kdump" service
systemctl disable kdump.service

#Configure Notification of Post-AIDE Scan Details
echo '05 4 * * * root /usr/sbin/aide --check | /bin/mail -s "$(hostname) - AIDE Integrity Check" root@localhost' >> /etc/crontab


#Disable Ctrl+Alt+Del Reboot
systemctl mask ctrl-alt-del.target

#Copy STIG audit rules to /var/log/audit/audit.d/audit.rules
touch /etc/audit/rules.d/audit.rules
touch /etc/audit/audit.rules
cat << EOF > /etc/audit/rules.d/audit.rules
-a always,exit -F arch=b32 -S chmod -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S chmod -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S chown -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S chown -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S fchmod -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S fchmod -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S fchmodat -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S fchmodat -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S fchown -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S fchown -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S fchownat -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S fchownat -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S fremovexattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S fremovexattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S fsetxattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S fsetxattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S lchown -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S lchown -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S lremovexattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S lremovexattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S lsetxattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S lsetxattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S removexattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S removexattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S setxattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b64 -S setxattr -F auid>=1000 -F auid!=4294967295 -F key=perm_mod
-a always,exit -F arch=b32 -S creat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S creat -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S creat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S creat -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S open -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S open -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S open -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S open -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S openat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S openat -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S openat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S openat -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b32 -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F arch=b64 -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -F key=access
-a always,exit -F path=/usr/sbin/semanage -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged-priv_change
-a always,exit -F path=/usr/sbin/setsebool -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged-priv_change
-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged-priv_change
-a always,exit -F path=/usr/sbin/restorecon -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged-priv_change
-a always,exit -F path=/usr/bin/passwd -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/sbin/unix_chkpwd -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/gpasswd -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/chage -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/sbin/userhelper -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/sudoedit -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/chsh -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/umount -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/sbin/postdrop -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/sbin/postqueue -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/libexec/openssh/ssh-keysign -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/libexec/pt_chown -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/bin/crontab -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F path=/usr/sbin/pam_timestamp_check -F perm=x -F auid>=1000 -F auid!=4294967295 -F key=privileged
-a always,exit -F arch=b32 -S rmdir -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b64 -S rmdir -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b32 -S unlink -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b64 -S unlink -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b32 -S unlinkat -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b64 -S unlinkat -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b32 -S rename -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b64 -S rename -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b32 -S renameat -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b64 -S renameat -F auid>=1000 -F auid!=4294967295 -F key=delete
-a always,exit -F arch=b32 -S init_module -F key=modules
-a always,exit -F arch=b64 -S init_module -F key=modules
-a always,exit -F arch=b32 -S delete_module -F key=modules
-a always,exit -F arch=b64 -S delete_module -F key=modules
-w /usr/sbin/insmod -p x -k modules
-w /usr/sbin/rmmod -p x -k modules
-w /usr/sbin/modprobe -p x -k modules
-w /var/log/tallylog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /etc/group -p wa -k audit_rules_usergroup_modification
-w /etc/gshadow -p wa -k audit_rules_usergroup_modification
-w /etc/shadow -p wa -k audit_rules_usergroup_modification
-w /etc/passwd -p wa -k audit_rules_usergroup_modification
-w /etc/security/opasswd -p wa -k audit_rules_usergroup_modification
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -F key=export
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -F key=export
-w /etc/sudoers -p wa -k actions
-w /etc/sudoers.d/ -p wa -k actions
-f 2
EOF
cat /etc/audit/rules.d/audit.rules > /etc/audit/audit.rules

#Configure AIDE rules

aide_conf="/etc/aide.conf"

groups=$(grep "^[A-Z]\+" $aide_conf | grep -v "^ALLXTRAHASHES" | cut -f1 -d '=' | tr -d ' ' | sort -u)

for group in $groups
do
	config=$(grep "^$group\s*=" $aide_conf | cut -f2 -d '=' | tr -d ' ')

	if ! [[ $config = *acl* ]]
	then
		if [[ -z $config ]]
		then
			config="acl"
		else
			config=$config"+acl"
		fi
	fi
	sed -i "s/^$group\s*=.*/$group = $config/g" $aide_conf
done

aide_conf="/etc/aide.conf"

groups=$(grep "^[A-Z]\+" $aide_conf | grep -v "^ALLXTRAHASHES" | cut -f1 -d '=' | tr -d ' ' | sort -u)

for group in $groups
do
	config=$(grep "^$group\s*=" $aide_conf | cut -f2 -d '=' | tr -d ' ')

	if ! [[ $config = *xattrs* ]]
	then
		if [[ -z $config ]]
		then
			config="xattrs"
		else
			config=$config"+xattrs"
		fi
	fi
	sed -i "s/^$group\s*=.*/$group = $config/g" $aide_conf
done

#Configure PAM
cat <<EOF > /etc/pam.d/system-auth
#%PAM-1.0
# This file is auto-generated.
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        sufficient    pam_fprintd.so
auth        [default=1 success=ok] pam_localuser.so
auth        required      pam_faillock.so preauth silent even_deny_root deny=3 unlock_time=never fail_interval=900
auth        [success=done ignore=ignore default=die] pam_unix.so try_first_pass
auth        [default=die] pam_faillock.so authfail even_deny_root deny=3 unlock_time=never fail_interval=900
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient    pam_sss.so forward_pass
auth        required      pam_deny.so
auth        required      pam_tally2.so deny=3 onerr=fail even_deny_root

account     required pam_faillock.so
account     required      pam_unix.so broken_shadow
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so
account     required      pam_tally2.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow try_first_pass use_authtok remember=5
password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so
password    requisite     pam_cracklib.so try_first_pass minlen=14 lcredit=-1 ucredit=-1 dcredit=-1 difok=3

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     optional      pam_oddjob_mkhomedir.so umask=0077
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_sss.so
EOF

#Fix login.defs CREATE_HOME line
sed -i '/CREATE_HOME/c CREATE_HOME yes' /etc/login.defs

#Add ICMP rules to /etc/sysctl.conf
echo 'net.ipv4.conf.default.send_redirects = 0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.send_redirects = 0' >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward = 0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.accept_redirects = 0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.accept_redirects = 0' >> /etc/sysctl.conf
echo 'net.ipv4.icmp_echo_ignore_broadcasts = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.accept_source_route = 0' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.accept_source_route = 0' >> /etc/sysctl.conf

#Create and add rules to SSSD file
touch /etc/sssd/sssd.conf
cat << EOF > /etc/sssd/sssd.conf
[sssd]
services = sudo, autofs, pam
EOF

updatedb

cat << "EOF" > /root/RUN_AFTER_INSTALL.sh
#!/bin/bash
echo "Set GRUB password"
grub2-setpassword
grub2-mkconfig -o /boot/grub2/grub.cfg
sed -i 's/set superusers="root"/ set superusers="grubuser"/' /etc/grub.d/01_userss
sed -i 's/password_pbkdf2 root/ password_pbkdf2 grubuser/' /etc/grub.d/01_users

echo "Set root password"
passwd

echo "Set hostname"
hostnamectl set-hostname

rm -f /root/Desktop/RUN_AFTER_INSTALL.sh
EOF
chmod +x /root/RUN_AFTER_INSTALL.sh

set +x

%end
