# This script installs Python on the instance, which is required by Ansible to execute many of its modules after it uploads them

set -e

if test -r /etc/os-release
then
	. /etc/os-release
	
	if test "$ID" = 'ubuntu'
	then
		export DEBIAN_FRONTEND=noninteractive
		
		sudo apt-get -qq update
		sudo apt-get -qq install python-minimal
		
		exit 0
	fi
elif test -r /etc/arch-release
then
	exec pacman --color never --noprogressbar --noconfirm -Sqy python
fi

echo 'Unknown, possibly unsupported operating system'
exit 1
