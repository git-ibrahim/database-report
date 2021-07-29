#!/bin/ksh
export ORACLE_HOME=<path>
export ORACLE_SID=<sid>
export PATH=$ORACLE_HOME/bin:$PATH

sqlplus -S sys/<password>@<db-service> as sysdba << EOF
@$HOME/markup.sql
spool $HOME/db_asm_rep.html
SET LINESIZE 150
SET PAGESIZE 9999
SET VERIFY off
COLUMN state FORMAT a11 HEAD 'STATE'
COLUMN type FORMAT a6 HEAD 'TYPE'
COLUMN total_mb FORMAT 999,999,999 HEAD 'TOTAL SIZE(GB)'
COLUMN free_mb FORMAT 999,999,999 HEAD 'FREE SIZE (GB)'
COLUMN used_mb FORMAT 999,999,999 HEAD 'USED SIZE (GB)'
COLUMN pct_used FORMAT 999.99 HEAD 'PERCENTAGE USED'

SELECT distinct name group_name , state state , type type ,
round(total_mb/1024) TOTAL_GB , round(free_mb/1024) free_gb ,
round((total_mb - free_mb) / 1024) used_gb ,
round((1- (free_mb / total_mb))*100, 2) pct_used from
gv\$asm_diskgroup where name='ARCH_DG01' and round((1- (free_mb / total_mb))*100, 2) > 80 ORDER BY name;
spool off
exit
EOF
count=`cat $logfile|wc -l`
#echo $count
if [ $count  -ge 4 ];
 then
  #################### MAIL SEND ##########################

MAIL_FROM="donotreply@abc.com"
MAIL_TO="xyz@xyz.com"
MAIL_CC="xyz@xyz.com"
HOSTNAME=`hostname`
MAIL_DATE=`date +'%d-%m-%Y %H:%M:%S'`
MAIL_DATE1=`date '+%d%m%Y_%H%M%S'`
ECHO="/bin/echo"
HOME_DIR=`pwd`

cd $HOME

SUBJECT="ASM DISKGROUP ARCH_DG REACHED 80% UTILIZATION $HOSTNAME DB BOX:($ORACLE_SID) STATUS REPORT DATED ${MAIL_DATE} "
FROM="donot_reply@xyz.com"

(echo "From: ${MAIL_FROM}"
 echo "To: ${MAIL_TO}"
 echo "Cc: ${MAIL_CC}"
 echo "subject: $SUBJECT"
 echo "MIME-Version: 1.0"
 echo "Content-Type: text/html"
 echo "Content-Disposition: inline"
 cat "$REPORT_HTML")|/usr/sbin/sendmail -oi -t $HOSTNAME@xyz.com
fi
