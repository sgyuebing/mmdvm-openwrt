#!/bin/sh

# 
# Copyright 2019-2020 Michael BD7MQB <bd7mqb@qq.com>
# This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2.0
# 

# Full path to DMR ID file
DMRIDFILE=/etc/mmdvm/DMRIds.dat
DMRIDFILE_TMP=/tmp/DMRIds.dat

# Full version
# curl 'https://www.radioid.net/static/users.csv' 2>/dev/null | awk -F ',' '{print $1"\t"$2"\t"$3"\t"$4"\t"$6}'  > ${DMRIDFILE}

# Pre-formatted version to speedup the update process
cd /etc/mmdvm
rm DMRIds.dat -f
wget http://123.60.74.175/files/DMRIds.dat
/etc/init.d/mmdvmhost restart

# Compact version
#wget -O ${DMRIDFILE} http://registry.dstar.su/dmr/DMRIds.php