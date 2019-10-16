# add in the kernel boot
# inst.ks=http://ansible.live/kicks.ks


lang en_US
keyboard us
timezone America/Toronto --isUtc
rootpw $1$cT9xDZhv$vsZtHOc/gL4UFRjwUynVU. --iscrypted
#platform x86, AMD64, or Intel EM64T
reboot --eject
text
url --url=http://mirror.csclub.uwaterloo.ca/centos/7/os/x86_64/
bootloader --location=mbr --append="rhgb quiet crashkernel=auto"
zerombr
clearpart --all --initlabel
autopart
auth --passalgo=sha512 --useshadow
selinux --disabled
firewall --enabled --ssh
skipx
firstboot --disable
%packages
@base
%end

