#! /bin/bash

HOST=maggiolo.net
USER=opensourceecology
PASSWD=whatever

ftp -nv $HOST|& 
$USER|& 
$PASSWD|& 

# print -p open $HOST
# print -p user $USER $PASSWD
# print -p binary
# for job2 in 3t 11 12 13   ; do 
#      print -p cd  $job2
#      CFNAME="$job2".chk
#      print -p  put /home/salazar/chk_data/$CFNAME $CFNAME
# done
echo "bye" |&
exit 0
