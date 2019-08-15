#!/bin/sh

DAEMON_FILE="daemon.sh"
JOBS_FILE="jobslist.dat"
DBNAME="jobs.db"
TBNAME="procs"
#https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself
ROOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"




#Function definitions

daemon_is_running() {
njobs=`ps aux | grep $DAEMON_FILE | wc -l`
njobs=$[$njobs-1]
echo $njobs
}


date_diff() {
stop_secs=`date -d"$1" +%s`
start_secs=`date -d"$2" +%s`
diff_secs=$[$stop_secs - $start_secs]
echo `date -u -d @"$diff_secs" +'%-Hh %-Mm %-Ss'`
}


qsubmit() {
if [ "$#" -eq "1" ]
then
sqlite3 $ROOTDIR/$DBNAME "insert into $TBNAME (start_time,run_time,stop_time,cmd,status) values ('NONE','NONE','NONE','$1','PENDING')"
jobid=`sqlite3 $ROOTDIR/$DBNAME "select MAX(id) from $TBNAME"`


#start="update $TBNAME set status = 'RUNNING',start_time=$(date '+%Y-%m-%d %H:%M:%S') where id = $jobid"
#stop="update $TBNAME set status = 'FINISHED',stop_time=`$(date '+%Y-%m-%d %H:%M:%S')` where id = $jobid"
#update_start="sqlite3 $ROOTDIR/$DBNAME \"$start\""
#update_stop="sqlite3 $ROOTDIR/$DBNAME \"$stop\""

fname="$ROOTDIR/jobs/j$jobid.sh"
echo "#!/bin/bash" >> $fname
echo "SECONDS=0" >> $fname
echo 'start_date=$(date "+%Y-%m-%d %H:%M:%S")' >> $fname
echo "sqlite3 $ROOTDIR/$DBNAME \"update $TBNAME set status = 'RUNNING', start_time = '\$start_date' where id = $jobid\"" >> $fname
#If we are given a script to run
if [ -f "$1" ]
then
echo "bash $1" >> $fname
#Else it's a command
else
echo "$1" >> $fname
fi

echo 'stop_date=$(date "+%Y-%m-%d %H:%M:%S")' >> $fname
echo "sqlite3 $ROOTDIR/$DBNAME \"update $TBNAME set status = 'FINISHED', stop_time = '\$stop_date' where id = $jobid\"" >> $fname
echo 'tdiff=`date -u -d @"$SECONDS"'" +'%-Hh %-Mm %-Ss'\`" >> $fname
echo "sqlite3 $ROOTDIR/$DBNAME \"update $TBNAME set run_time = '\$tdiff' where id = $jobid\"" >> $fname

echo "bash $fname" >> $ROOTDIR/$JOBS_FILE
fi 
}

update_table() {
imin=`sqlite3 $ROOTDIR/$DBNAME "select min(id) from $TBNAME"`
imax=`sqlite3 $ROOTDIR/$DBNAME "select max(id) from $TBNAME"`


if [ -z $imin ]
then
:
else

for (( i=$imin; i<=$imax; i++ ))
do
res=`sqlite3 $ROOTDIR/$DBNAME "select start_time,status from $TBNAME where id = $i"`

IFS='|' read -ra dates <<< "$res"
dstart="${dates[0]}"
status="${dates[1]}"


if [ "$status" == "RUNNING" ]
then
now=`date "+%Y-%m-%d %H:%M:%S"`
ddiff=`date_diff "$now" "$dstart"`

sqlite3 $ROOTDIR/$DBNAME "update $TBNAME set run_time = '$ddiff' where id = $i"
fi
done
fi
}


qqueue() {

update_table

colnames="ID\tTSTART\tTRUN\tTSTOP\tCOMMAND\tSTATUS"
echo -e $colnames
imin=`sqlite3 $ROOTDIR/$DBNAME "select min(id) from $TBNAME"`
imax=`sqlite3 $ROOTDIR/$DBNAME "select max(id) from $TBNAME"`

if [ -z $imin ]
then
:
else

echo

for (( i=$imin; i<=$imax; i++ ))
do
res=`sqlite3 $ROOTDIR/$DBNAME "select * from $TBNAME where id = $i"`

if [[ $res != *FINISHED ]]
then
:
echo -e "${res//|/\t}"
fi
done
fi
}


init_db() {
if [ -f "$ROOTDIR/$DBNAME" ]
then
:
else
sqlite3 $ROOTDIR/$DBNAME "create table $TBNAME (id INTEGER PRIMARY KEY, start_time TEXT,run_time TEXT, stop_time TEXT, cmd TEXT, status TEXT)"    
fi
}






#Now run the initialization
mkdir -p $ROOTDIR/jobs
#Is the daemon running
isrunning="$(daemon_is_running)"

if [ "$isrunning" -gt "0" ]
then
:
#echo "Daemon is running"
else
nohup bash $ROOTDIR/$DAEMON_FILE $ROOTDIR/$JOBS_FILE &
#echo "Starting the daemon now"
fi


#Initialize the database
init_db

export -f qsubmit
export -f qqueue
