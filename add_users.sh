#!/bin/bash
# This does it old school and adds users to the sudoers list
# Probably better to use - "newusers /vagrant/userlist.txt"

for i in $(cat /vagrant/userlist.txt | awk -F ":" '{print $1}')
  do  
    useradd -d /home/${i} -m ${i} 
    passwd -d ${i}
    echo "ceph123" | passwd ${i} --stdin
    echo "${i} ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${i}
    sudo chmod 0440 /etc/sudoers.d/${i}
    chown ${i}:${i} /home/${i}/
    #cp .bashrc .bash_profile /home/$i
    #chown $i:wheel /home/${i}/.bashrc
    #chown $i:wheel /home/${i}/.bash_profile
  done
