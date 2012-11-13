# !bin/bash -x

source config.cfg
source scripts/alert_monitor.sh

#PRE_CMD="$ISQL $HOST:$PORT -U $USER -P $PASS verbose=on echo=on errors=stdout banner=off prompt=off"

isql=${isql_path:-"$virtuoso_home/bin/isql"}

if [ ! $isql ]; then
	echo "Could not find isql."
	exit 1
fi

isql_cmd="$isql localhost:$isql_port -U $user"
isql_pass="-P $isql_password"

##
# define functions
#

##
# print the help messages for use

function _usage(){
 cat <<"USAGE"
	
	select from one of the following options:
	[start|stop|restart|load|clear|index|destory]

	start	: start the server
	stop	: shutdown the server gracefully
	restart	: restart the server
	load	: load directory of files. the graph can be specified by using load into <graphname>
	clear	: clear graph from database specified by string
	index	: generate the index for facet
	
	-r : specifify recursive loading of files in subdirectories
	-t : specify the type of file to load, ntriples, rdf, or nquads 
USAGE

echo $USAGE
}

##
# place all the checks that need to be done here
function system_check(){
	if [ ! $virtuoso_home ]; then echo "virtuoso_home is not configured. Please set VIRTUOSO_HOME in your .bash_profile"; exit 1; fi
}

##
# turn on the logging of isql statements 
# 
function trace_on(){
	run_cmd "trace_on('errors','exec');"
}
##
# handle the process of loading virtuso

function load(){
	if [ -f "$1" ];then
        echo "have not added support for loading a single file yet"
	elif [ -d "$1" ]
	then
			
			status check
			if $check ; then
				echo "loading directory: $1"
				
				add_dirlist $1
				start_loader
				
				echo "Finished."
				exit 1
			else
				echo "There is no virtuoso running. please start using [start] option"
				exit 1
			fi
	else
		echo "please supply a real file/directory: $1"
		exit 1
	fi
}

##
# start rdf_loaders

function start_loader(){
	for x in {1..5} ; do rdf_loader_run  ;   done
} 

# check the status of the virtuoso instance
# will need to find the specific instance
# not sure how this is done at the moment.

# could use lsof to check the http port if there is a webservice running?
function status(){
	local _virtuoso_status=$1
 	local _status_result=$(ps ax | grep -v grep | grep $virtuoso | awk '{print $1}')

	if [ $_status_result ]; then
		_status_result=true
	else
		_status_result=false
	fi

	eval $_virtuoso_status="'$_status_result'" 
}

# load a directory of ntriple files into the virtuoso server
function add_dirlist (){
	if [ $RECURSIVE ]
	then
			run_cmd "ld_dir_all('$1','*.$input.gz','$graph');" logs/virtuoso_load.log
	else	
			run_cmd "ld_dir('$1','*.$input.gz','$graph');" logs/virtuoso_cmd.log
	fi
 
 echo "Directory listing for $1 added to load list."
}
# Done - <sometime> ms.
function error_check(){
   case "$1" in
     *"Error"*)
      # echo "$CMD"
       exit 1
       ;;
    esac
}

# start new rdf_loader as background job
function rdf_loader_run(){
${isql_cmd} ${isql_pass} verbose=on echo=on errors=stdout banner=off prompt=off exec="rdf_loader_run(); exit;" &> /dev/null &
}

# prints statistics on the current loading of files
function load_status(){
 return false
}

# completely reset the load list
function clear_load_list(){
	run_cmd "delete from load_list;" logs/virtuoso_cmd.log
}

# update the load list files that were not able to be loaded and try again
function reset_load_list(){
	run_cmd "update load_list set ll_state=0 where ll_state=1" /logs/virtuoso_cmd.log
}

# listen for errors in file loading
function listen(){
return false
}

# start virtuoso in background
# should check to make sure it is up
# and running before finishing command
function start(){
	
	if [ ! -f  "${config_dir}/virtuoso.log" ]; then
		echo "Cannot find the virtuoso.log file to monitor startup"
		echo "This may be because this is the first time you are starting virtuoso."
	fi

	status check
	if $check
	then
		echo "$virtuoso is running"
	 	return 0
	fi
	
	`./$virtuoso > /dev/null  &`
	
	tail -n 0 -F "${config_dir}/virtuoso.log" | while read LOGLINE
	do
		   [[ "${LOGLINE}" == *"Server online at $port"* ]] && pkill -P $$ tail
		   [[ "${LOGLINE}" == *"There is no configuration file virtuoso.ini"* ]] && echo "No virtuoso.ini file found" && pkill -P $$ tail
	done

	echo "Starting server.............................................................................[Ok]"
}

# stop the server gracefully
# *** Error S2801: [Virtuoso Driver]CL033: Connect failed to 
function stop(){

	if [ ! -f  "${config_dir}/virtuoso.log" ]; then
		echo "Cannot find the virtuoso.log file."
		echo "This log is used to monitor virtuoso and is found in the same"
		echo "directory as the virtuoso.ini file. Set the $config_dir variable to that directory"
		exit 1
	fi

	status check
	if [ ! $check ]; then
		echo "No $VIRTUOSO to shutdown"
		exit 1
	fi

	${isql_cmd} ${isql_pass} "-K > /dev/null"

	tail -n 1 -f virtuoso.log | while read LOGLINE
	do	
		   [[ "${LOGLINE}" == *"Server shutdown complete"* ]] && pkill -P $$ tail
	done

	echo "Server shutdown complete........................................................................[OK]"
}

##
# load a single file into the virtuoso server
# if not specified default graph is used.
function load_file () {
    CMD=$($ISQL $HOST:$PORT -U $USER -P $PASS verbose=on echo=on errors=stdout banner=on prompt=off exec="DB.DBA.TTLP_MT(file_to_string_output('$1'),'', '$GRAPH',$FLAGS);")
    
   case "$CMD" in
    *"Error"*)
     echo "$CMD"

     ##
     # implement removal of problem lines to continue loading
     # use example: sed -n -e 120p -e 145p -e 1050p /var/log/syslog
     # where numbers are specific line numbers to be deleted from the file.
     # after removing the line start from the offset when the file stopped
     # loading

     exit 1
    ;;
    *"Done"*)
     echo "----> Successfully loaded file: $1"
   esac
}

##
# check for errors while running isql commands on the server
function trigger(){
	local _tail_pid=$1

	while  read line; do

		case $line in

			*"Error S2801"*)
				echo "Not able to connect to isql. see log for details"
				kill $_tail_pid
				kill $$
				;;

			*"Error 37000"*)
				echo "Synatx error. see log for details"
				;;
			*"Error"*)
				echo "unhandled error. see log for details."
				kill -9 $1
				;;

			*"Done"*)
				echo "--> done."
				kill -9 $1
				;;
		esac
 	done
}
##
# update the facet
#
function update_facet(){
	echo "Updating facet browser. This could take awhile....."
 	
 	run_cmd "RDF_OBJ_FT_RULE_ADD(null,null,'All');"  logs/virtuoso_cmd.log
 	run_cmd "VT_INC_INDEX_DB_DBA_RDF_OBJ();"  logs/virtuoso_cmd.log
	#run_cmd "urilbl_ac_init_db();"  logs/virtuoso_cmd.log
	#run_cmd "s_rank();"  logs/virtuoso_cmd.log

	echo "Done building index"
}


function run_cmd(){

echo "Running: $1"
if [ $2 ]; then
	echo "Monitor for completion = yes"
	logfile=$2
	tail -n0 -F $logfile 2>/dev/null | trigger $! &
else
	logfile="/dev/null"
fi

${isql_cmd} ${isql_pass} <<EOF &> $logfile
	$1 
	exit;
EOF

}


##
# execute rdfs subClassOf inference


##
# delete specified graph
# uss log_enable(3,1) function to
# set the transaction to autocomit on 
# each operation
function delete_graph() {
  
  PRE_CMD="$ISQL $HOST:$PORT -U $USER -P $PASS verbose=on blobs=on echo=on errors=stdout banner=on prompt=off "
  graphs=$($PRE_CMD exec="db.dba.sparql_select_known_graphs();")
  
  array=( $graphs )

  needle=false
  case "${array[@]}" in
  	*\ "$1"\ *)
  			needle=true	
		;;
		*)
		  echo "did not find the specified graph"
		::
   esac

	if $needle 
		then
			echo "deleting graph $1"
			$CMD=$($PRE_CMD exec="log_enable(3,1); SPARQL CLEAR GRAPH <$1>;"  &)
			echo $CMD
		fi
  #CMD=$($ISQL $HOST:$PORT -U $USER -P $PASS verbose=on echo=on errors=stdout banner=on prompt=off exec="log_enable(3,1); SPARQL CLEAR GRAPH <$GRAPH>;") 
}

#######################################################################################33
#Start the script
#
#######################################################################################
if [ $# == 0 ];
then 
   _usage
  exit 1
fi

system_check

OPTIND=1
while getopts "rt:" opt; do
  case $opt in      
      t)
        if [ "$OPTARG" == "ntriples" ]; then
        	input="nt"
        elif [ "$OPTARG" == "rdf" ]; then
        	input="rdf"
        elif [ "$OPTARG" == "nquad" ]; then
        	input="nq"
        fi
      ;;
      r)
    	RECURSIVE=true
      ;;  
    \?)
       echo "Invalid option: $OPTARG" >&2
      ;;
  esac
done

shift $(($OPTIND - 1))

case $1 in
	start)
		start
	;;
	stop)
		stop
	;;
	restart)
		stop
		start
	;;
	delete)
		if [ "$2" ]; then
			delete_graph $2
		else
			echo "specify a graph name to delete"
			exit 1
		fi
	;;
	load)
		
		if [ ! "$2" ];
		then
			echo "must supply file or directory to load"
			exit 1
		else
			if [[ "$3" == "into" && $4 ]]; then
				echo "loading all $input files into $4"
				graph=$4
			fi
			clear_load_list


			original=`pwd`
			cd $2
			dir=`pwd`
			cd  $original
		    load $dir
		    exit 0
		fi
	;;

	index)
		update_facet

		;;
	destroy)
		echo "Do you really want to destory the database?[y/n]:"
		read answer

		if [ $answer == "y" ]; then
			 rm ./{virtuoso.log,virtuoso.db,virtuoso.lck,virtuoso-temp.db,virtuoso.trx,virtuoso.pxa}
		else
			echo "potential disaster averted"
			exit 1
		fi
		;;
	*)
		echo "invalid choice"
		_usage
	;;
esac


