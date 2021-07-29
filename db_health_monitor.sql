set lines 200 pages 200
set feedback off
@$HOME/markup.sql
spool $HOME/db_health_rep.html

select '<H1 align="center">Database Healthcheck Details</H1>' as Report_Name from dual;

select 'Report Started at : '||systimestamp as status from dual;

select '<H1 align="center">******** DB Version ********</H1>'  Title from dual;
select * from v$version where banner like 'Oracle%';

select name "DB name" from v$database;

select '<H1 align="center">******** CPU Memory Details ********</H1>'  Title from dual;

select a.INST_ID,(a.value / b.value)*100  "% Recursive CPU Usage"
from gV$SYSSTAT a, gV$SYSSTAT b
where a.name = 'recursive cpu usage'
and b.name = 'CPU used by this session'
and a.inst_id=b.inst_id order by inst_id;


select a.INST_ID,(a.value / b.value)*100 "% CPU for Parsing"
from gV$SYSSTAT a, gV$SYSSTAT b
where a.name = 'parse time cpu'
and b.name = 'CPU used by this session'
and a.inst_id=b.inst_id order by inst_id;

select '<H1 align="center">******** Instance Details ********</H1>'  Title from dual;

select inst_id,instance_name,host_name,to_char(startup_time,'DD-MM-YYYY HH24:MI:SS') Startup_time,STATUS, archiver from gv$instance;

select '<h1 align="center">******** DB Response ********</h1>'  Title from dual;

select inst_id,to_char(begin_time,'hh24:mi') time, round( value * 10, 2) "Response Time (ms)" from gv$sysmetric where metric_name='SQL Service Response Time';

select '<h1 align="center">******** Blocking Session Details ********</h1>'  Title from dual;

select inst_id,sid,username,blocking_instance,blocking_session,last_call_et from gv$session where blocking_session_status='VALID' order by last_call_et desc;
select a.inst_id,a.sid,a.username,a.status,a.last_call_et,a.machine,a.client_identifier,a.sql_id,a.event
,a.service_name,b.blk_inst_id,b.blk_sid,b.blk_username,b.blk_status,b.blk_last_call_et,
b.blk_machine,b.blk_client_identifier,b.blk_sql_id,b.blk_event,b.blk_service_name
from
(select inst_id,sid,username,blocking_instance,blocking_session,last_call_et,status,machine,client_identifier,sql_id,event
,service_name from gv$session where blocking_session_status='VALID') a,
(select inst_id blk_inst_id,sid blk_sid, serial# blk_serial#,last_call_et blk_last_call_et,username blk_username
,status blk_status,machine blk_machine,client_identifier blk_client_identifier,sql_id blk_sql_id,event blk_event
,service_name blk_service_name from gv$session) b
where a.blocking_instance =b.blk_inst_id(+)
and a.blocking_session=b.blk_sid(+);

select '<h1 align="center">******** Session Counts ********</h1>'  Title from dual;

select inst_id,status,cnt session_count from (select inst_id,status,count(1) cnt from gv$session group by (inst_id,status) order by inst_id,status);

select '<h1 align="center">******** Long Running Sessions ********</h1>'  Title from dual;

select round(l.time_remaining/60,2) rem_mins,round(l.elapsed_seconds/60,2) ela_mins,round((l.sofar/l.totalwork)*100,2) perc,l.inst_id,sid,serial#,opname,target,target_desc,start_time,last_update_time,message,username,sql_id from gv$session_longops l where sofar<>totalwork and l.elapsed_seconds >0 and l.totalwork >0 order by 1 desc;

select '<h1 align="center">******** Transactions Running for more than 5 minutes ********</h1>'  Title from dual;

select s.inst_id,s.sid,s.serial#,t.addr,t.used_ublk,t.start_date,s.username,s.status,s.osuser,s.machine,s.sql_id,s.logon_time,s.last_call_et,s.service_name,s.client_identifier from gv$session s, gv$transaction t
where s.taddr=t.addr and t.inst_id=s.inst_id and t.start_date < (sysdate - (60*5)/86400)
order by t.start_date;

select '<h1 align="center">******** Sessions Running for more than 60 Seconds ********</h1>'  Title from dual;

select INST_ID,SID,LAST_CALL_ET,SERIAL#,USERNAME,STATUS,OSUSER,MACHINE,PROGRAM,TYPE,SQL_ID,PREV_SQL_ID,MODULE,ACTION,LOGON_TIME,BLOCKING_INSTANCE,BLOCKING_SESSION,EVENT
,WAIT_CLASS,WAIT_TIME,SECONDS_IN_WAIT,STATE,SERVICE_NAME,client_identifier
from gv$session  where LAST_CALL_ET > 60 and status='ACTIVE' and username is not null order by LAST_CALL_ET desc;

select '<h1 align="center">******** Sessions Running for more than 3 hrs ********</h1>'  Title from dual;

select INST_ID,SID,LAST_CALL_ET,SERIAL#,USERNAME,STATUS,OSUSER,MACHINE,PROGRAM,TYPE,SQL_ID,PREV_SQL_ID,MODULE,ACTION,LOGON_TIME,BLOCKING_INSTANCE,BLOCKING_SESSION,EVENT
,WAIT_CLASS,WAIT_TIME,SECONDS_IN_WAIT,STATE,SERVICE_NAME,client_identifier
from gv$session  where LAST_CALL_ET > 10800 and status='ACTIVE' and username is not null order by LAST_CALL_ET desc;

select '<h1 align="center">********Dead Lock Info ********</h1>'  Title from dual;

SELECT a.session_id, username, TYPE, mode_held, mode_requested, lock_id1,lock_id2
FROM gv$session b, dba_blockers c, dba_locks a
WHERE c.holding_session = a.session_id AND c.holding_session = b.sid;

select '<h1 align="center">******** Tablespace Usage Details ********</h1>'  Title from dual;


select a.tablespace_name,a.used File_size,a.maxallocated,(a.used-b.freespace) Actualused,a.maxallocated-(a.used-b.freespace) actuallFree,
case when round(((a.used-b.freespace)/a.maxallocated)*100) > 90 then
 '<span style="background-color:#FF0000;display:block;overflow:auto">' || to_char(round(((a.used-b.freespace)/a.maxallocated)*100)) || '</span>'
else to_char(round(((a.used-b.freespace)/a.maxallocated)*100)) end "%used",
100 - round(((a.used-b.freespace)/a.maxallocated)*100) "%Free"
    from
    (SELECT tablespace_name, sum(bytes) used,sum(maxallocated) maxallocated
    from
    (SELECT tablespace_name,
        ROUND(a.bytes/1048576) bytes,
        CASE WHEN maxbytes<A.BYTES THEN ROUND(A.bytes/1048576) ELSE ROUND(A.maxbytes/1048576) END maxallocated
FROM sys.DBA_DATA_FILES a
   )
   GROUP BY tablespace_name)a,
   (
   SELECT tablespace_name ,ROUND(SUM(bytes/1048576)) freespace
          FROM dba_free_space
         WHERE tablespace_name NOT IN ('UNDOTBS')
         GROUP BY TABLESPACE_NAME
   )b
   where a.tablespace_name=b.tablespace_name
   order by 6 desc;

select '<h1 align="center">******** UNDO Usage ********</h1>'  Title from dual;

select db.tablespace_name,db.totsize_mb,db.freemb,var.used_mb,var.inst_id from
(
select tablespace_name,round(sum(totsize_mb),1) totsize_mb,round(sum(freemb),1) freemb from(
select tablespace_name,sum(bytes)/1024/1024 totsize_mb,0 freemb from dba_data_files where tablespace_name like 'UNDO%' group by tablespace_name
union
select tablespace_name,0 totsize_mb,sum(bytes)/1024/1024 freemb from dba_free_space where tablespace_name like 'UNDO%' group by tablespace_name
)
group by tablespace_name) db,
(SELECT sum(t.used_ublk*(1024*16)/1024/1024) used_mb,t.inst_id, r.tablespace_name
FROM sys.gv_$transaction t, sys.dba_rollback_segs  r
WHERE (t.xidusn = r.segment_id)
group by t.inst_id, r.tablespace_name) var
where db.tablespace_name=var.tablespace_name(+);

select '<h1 align="center">******** TEMP Usage ********</h1>'  Title from dual;

SELECT A.tablespace_name tablespace, D.mb_total,SUM (A.used_blocks * D.block_size)/1024/1024 mb_used,
D.mb_total - SUM(A.used_blocks * D.block_size)/1024/1024 mb_free
FROM gv$sort_segment A,
(SELECT B.name, C.block_size, SUM(C.bytes)/1024/1024 mb_total FROM gv$tablespace B, gv$tempfile C
WHERE B.ts#= C.ts# GROUP BY B.name, C.block_size) D
WHERE A.tablespace_name = D.name
GROUP by A.tablespace_name, D.mb_total;

select '<h1 align="center">******** SQL using more than 1 GB TEMP Space ********</h1>'  Title from dual;

select s.inst_id, s.sid, s.serial#, a.sql_id,s.status,s.username,osuser,u.tablespace,
round(((u.blocks*p.value)/1024/1024),2) size_mb,a.sql_text
from gv$sort_usage u,gv$session s,gv$sqlarea a,v$parameter p
where s.saddr = u.session_addr
and a.address (+) = s.sql_address
and a.hash_value (+) = s.sql_hash_value
and p.name = 'db_block_size'
and s.username != 'SYSTEM'
and s.inst_id=u.inst_id(+) and s.inst_id=a.inst_id(+)
group by s.inst_id,a.sql_id,s.sid ,s.status, s.serial#,s.username,osuser,a.sql_text,u.tablespace,
round(((u.blocks*p.value)/1024/1024),2)
having round(((u.blocks*p.value)/1024/1024),2) > 1024
order by 9 desc;

select '<h1 align="center">******** PGA Usage ********</h1>'  Title from dual;

select  inst_id,round(sum(PGA_USED_MEM),1) PGA_USED_MEM_MB,round(sum(PGA_max_MEM),1) PGA_max_MEM_MB ,
round(sum(PGA_ALLOC_MEM)) PGA_ALLOC_MEM_MB,count(1) Session_Count from (
select s.inst_id, PGA_USED_MEM/1024/1024 PGA_USED_MEM, PGA_ALLOC_MEM/1024/1024 PGA_ALLOC_MEM
,pga_max_mem/1024/1024 pga_max_mem
from gv$session s
, gv$process p
Where s.paddr = p.addr
and s.inst_id = p.inst_id
order by PGA_USED_MEM desc
)
group by inst_id
order by inst_id;

select '<h1 align="center">******** Service Distribution ********</h1>'  Title from dual;

select node,
rtrim(xmlagg(xmlelement(e,name||', ')).extract ('//text()'),',') services
from
(
select 'node2' node, name from(
select name from gv$active_services where inst_id=2
minus
select name from gv$active_services where inst_id=1
)
union
select 'node1' node, name from(
select name from gv$active_services where inst_id=1
minus
select name from gv$active_services where inst_id=2
)
union
select 'common' node, name from(
select name from gv$active_services where inst_id=1
intersect
select name from gv$active_services where inst_id=2
)  order by name
)
group by node
order by 1;

select '<h1 align="center">******** Service Wise Session Counts ********</h1>'  Title from dual;

select service_name, inst_id,cnt from
(select inst_id,service_name,count(1) cnt from gv$session where service_name is not null group by inst_id,service_name order by service_name,inst_id);

column REMAINING format 9999999999999999999999999999
column LAST_NUMBER format 9999999999999999999999999999
column MAX_VALUE format 9999999999999999999999999999

select '<h1 align="center">******** Sequence Details ********</h1>'  Title from dual;

select sequence_owner,sequence_name,min_value,max_value,increment_by,last_number,(max_value-last_number) remaining,round(last_number/max_value * 100,2) used_perc
from dba_sequences where last_number>0  and SEQUENCE_OWNER in('OLAP','MAP_USER') order by 8 desc;

SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off
COLUMN group_name             FORMAT a20           HEAD 'Disk Group|Name'
COLUMN sector_size            FORMAT 99,999        HEAD 'Sector|Size'
COLUMN block_size             FORMAT 99,999        HEAD 'Block|Size'
COLUMN allocation_unit_size   FORMAT 999,999,999   HEAD 'Allocation|Unit Size'
COLUMN state                  FORMAT a11           HEAD 'State'
COLUMN type                   FORMAT a6            HEAD 'Type'
COLUMN total_mb               FORMAT 999,999,999   HEAD 'Total Size (MB)'
COLUMN used_mb                FORMAT 999,999,999   HEAD 'Used Size (MB)'
COLUMN pct_used               FORMAT 999.99        HEAD 'Pct. Used'

select '<h1 align="center">********Disk Space / ASM Diskgoups  ********</h1>'  Title from dual;

SELECT
    name                                     group_name
  , sector_size                              sector_size
  , block_size                               block_size
  , allocation_unit_size                     allocation_unit_size
  , state                                    state
  , type                                     type
  , total_mb                                 total_mb
  , (total_mb - free_mb)                     used_mb
  , ROUND((1- (free_mb / total_mb))*100, 2)  pct_used
FROM v$asm_diskgroup
ORDER BY name;

col OBJECT_NAME format a60

select '<h1 align="center">******** Invalid Objects deatils ********</h1>'  Title from dual;

SELECT OWNER, OBJECT_NAME, OBJECT_TYPE, STATUS  FROM DBA_OBJECTS WHERE STATUS = 'INVALID' and OWNER not in ('MGMT_VIEW','SYS','DBSNMP','SYSMAN','SYSTEM','LBACSYS','OUTLN','FLOWS_FILES','MDSYS','ORDSYS','EXFSYS','WMSYS','APPQOSSYS','APEX_030200','ORDDATA','ANONYMOUS','XDB','ORDPLUGINS','SI_INFORMTN_SCHEMA','OLAPSYS','ORACLE_OCM',
'XS$NULL','MDDATA','DIP','APEX_PUBLIC_USER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR');

col INDEX_NAME format a60
select '<h1 align="center">******** Invalid Index  deatils ********</h1>'  Title from dual;

SELECT OWNER, INDEX_NAME,TABLE_NAME, STATUS  FROM DBA_INDEXES WHERE STATUS = 'INVALID' and OWNER not in ('MGMT_VIEW','SYS','DBSNMP','SYSMAN','SYSTEM','LBACSYS','OUTLN','FLOWS_FILES','MDSYS','ORDSYS','EXFSYS','WMSYS','APPQOSSYS','APEX_030200','ORDDATA','ANONYMOUS','XDB','ORDPLUGINS','SI_INFORMTN_SCHEMA','OLAPSYS','ORACLE_OCM',
'XS$NULL','MDDATA','DIP','APEX_PUBLIC_USER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR');

select '<h1 align="center">******** USER ACCOUNT STATUS ********</h1>' Title from dual;

SELECT USERNAME,ACCOUNT_STATUS from dba_users where account_status not in('OPEN') and username not in ('MGMT_VIEW','SYS','DBSNMP','SYSMAN','SYSTEM','LBACSYS','OUTLN','FLOWS_FILES','MDSYS','ORDSYS','EXFSYS','WMSYS','APPQOSSYS','APEX_030200','ORDDATA','ANONYMOUS','XDB','ORDPLUGINS','SI_INFORMTN_SCHEMA','OLAPSYS','ORACLE_OCM',
'XS$NULL','MDDATA','DIP','APEX_PUBLIC_USER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR');

col INDEX_NAME format a60
select '<h1 align="center">******** Unusable Index details ********</h1>'  Title from dual;

select OWNER, INDEX_NAME,TABLE_NAME, STATUS from dba_indexes where status='UNUSABLE' and OWNER not in ('MGMT_VIEW','SYS','DBSNMP','SYSMAN','SYSTEM','LBACSYS','OUTLN','FLOWS_FILES','MDSYS','ORDSYS','EXFSYS','WMSYS','APPQOSSYS','APEX_030200','ORDDATA','ANONYMOUS','XDB','ORDPLUGINS','SI_INFORMTN_SCHEMA','OLAPSYS','ORACLE_OCM',
'XS$NULL','MDDATA','DIP','APEX_PUBLIC_USER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR');

select 'Report Finished at : '||systimestamp  as status from dual;

select 'Thanks <BR> DBA Team' as status from dual;

spool off