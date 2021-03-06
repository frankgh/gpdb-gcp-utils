#!/usr/bin/env bash

. config.sh
. common.sh

setup_ssh()
{
	for host in $hosts; do
		# generate pub keys
		gcp_ssh $host -- bash -ex <<EOF
[ -f ~/.ssh/id_rsa ] || ssh-keygen -P '' -f ~/.ssh/id_rsa
EOF

		# fetch all pub keys
		gcp_scp $host:.ssh/id_rsa.pub tmp/$host.pub
		# combine all pub keys
		cat tmp/$host.pub >> tmp/all.pub
	done

	for host in $hosts; do
		# authorize all pub keys
		gcp_scp tmp/all.pub $host:/tmp/
		gcp_ssh $host -- bash -ex <<EOF
cat /tmp/all.pub >> ~/.ssh/authorized_keys
EOF
	done

	for host in $hosts; do
		# mark all the pub keys as known
		gcp_ssh $host -- bash -ex <<EOF
for h in $hosts; do
  ssh -o StrictHostKeyChecking=no \$h :
done
EOF
	done
}

# install depends, setup sysctl and limits
setup_system()
{
	gcp_scp misc/ $mdw:/tmp/

	gcp_ssh $mdw -- bash -ex <<EOF
. $gphome/greenplum_path.sh

# generate hostfiles
cat <<EOF1 >~/hostfile.all
$(join_hostnames $'\n' "$hosts")
EOF1
cat <<EOF1 >~/hostfile.segs
$(join_hostnames $'\n' "$sdws")
EOF1

# copy helper scripts to all segs
gpscp -r -f ~/hostfile.segs /tmp/misc =:/tmp/

# deploy and run the scripts
gpssh -f ~/hostfile.all <<EOF1
	sudo cp /tmp/misc/limits.conf /etc/security/limits.d/99-gpdb.conf
	sudo cp /tmp/misc/sysctl.conf /etc/sysctl.d/99-gpdb.conf

	sudo sysctl -p /etc/sysctl.d/99-gpdb.conf

	cd /tmp/misc
	sudo bash -ex ./$install_deps_script
EOF1
EOF
}

rm -rf tmp
mkdir tmp

setup_ssh
setup_system
