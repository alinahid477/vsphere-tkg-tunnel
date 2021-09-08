#!/bin/bash
chmod 600 /root/.ssh/id_rsa
printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x

source ~/binaries/tunnel.sh

cd ~

/bin/bash