storiq-lib-raid
===============

This is the RAID management library for the StorIQ tools. This library is necessary for raid_cli, raid_control, raid_monitor, raid_gui and the webmin raid-storiq module.

Simply build the content of the repository as a Debian package after putting away the README and LICENSE files :

dpkg --build .  ../storiq-lib-raid_<version>_all.deb

And install the package. The resulting package works on Squeeze and Wheezy.

For Adaptec, LSI Megaraid, 3Ware and Xyratex controllers, you'll need the additional proprietary command line tools. LVM, MD raid and DDN controllers work without any tools other than the usual lvm2 tools, mdadm and ssh.
