#!/bin/bash

################# DB REPORT #################

export ORACLE_SID=<sid>
export ORACLE_HOME=<path>
PATH=$PATH:$ORACLE_HOME/bin

rm -f $HOMEdb_health_rep.html
CurPath=$PATH

sqlplus -s -M "HTML ON ENTMAP OFF " '<user>/<password>@<db-service>' << EOF

@$HOME/db_health_monitor.sql
EOF

cd $HOME

chmod 777 *.html

#################### MAIL SEND ##########################

RCPT_LIST="xyz@xyz.com"
HOSTNAME=`hostname`
MAIL_DATE=`date +'%d-%m-%Y %H:%M:%S'`
MAIL_DATE1=`date '+%d%m%Y_%H%M%S'`
ECHO="/bin/echo"
HOME_DIR=`pwd`

cd $HOME

SUBJECT="(Server: $HOSTNAME DB Report: $ORACLE_SID STATUS REPORT DATED ${MAIL_DATE} "
FROM="donotreply@xyz.com"

/bin/mailx -s "$SUBJECT" -a "$HOME/db_health_rep.html" $RCPT_LIST
