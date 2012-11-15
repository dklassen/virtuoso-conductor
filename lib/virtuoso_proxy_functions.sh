# start virtuoso in background
# should check to make sure it is up
# and running before finishing command
function start(){

	# check the virtuoso 
	if [ ! $location ]; then
		echo "Location was not set"
		exit 1
	fi
	
	if [ ! -f ${virtuoso_ini} ]; then
		echo "no virtuoso.ini found in the configured directory: $location. Please copy a valid virtuoso.ini file into that location"
		exit 1
	fi

	if [ ! -f  "${location}/virtuoso.log" ]; then
		echo "Cannot find the virtuoso.log file to monitor startup"
		echo "This may be because this is the first time you are starting virtuoso."
		echo "Creating the file now"
		touch ${location}/virtuoso.log
	fi

	status check
	if $check
	then
		echo "$virtuoso is running"
	 	return 0
	fi
	
	if [ -f $virtuoso ];then
		`$virtuoso > /dev/null  &`
	else
		echo "missing $virtuoso. may need to run setup"
		exit 1
	fi
	
	tail -n 0 -F "${location}/virtuoso.log" | while read LOGLINE
	do
		   [[ "${LOGLINE}" == *"Server online at $port"* ]] && pkill -P $$ tail
		   [[ "${LOGLINE}" == *"Virtuoso is already runnning"* ]] && echo "Virtuoso already running" && pkill -P $$ tail
		   [[ "${LOGLINE}" == *"There is no configuration file virtuoso.ini"* ]] && echo "No virtuoso.ini file found" && pkill -P $$ tail
	done

	echo "Starting server.............................................................................[Ok]" && return 0
}

# stop the server gracefully
# *** Error S2801: [Virtuoso Driver]CL033: Connect failed to 
function stop(){

	if [ ! -f  "${location}/virtuoso.log" ]; then
		echo "Cannot find the virtuoso.log file."
		echo "This log is used to monitor virtuoso and is found in the same"
		echo "directory as the virtuoso.ini file. Set the $config_dir variable to that directory"
		exit 1
	fi

	status check

	if [[ $check == "false" ]]
	then
		echo "No $virtuoso to shutdown"
		exit 1
	fi

	${isql_cmd} ${isql_pass} "-K > /dev/null"

	tail -n 1 -f "${location}/virtuoso.log" | while read LOGLINE
	do	
		   [[ "${LOGLINE}" == *"Server shutdown complete"* ]] && pkill -P $$ tail
	done

	echo "Server shutdown complete........................................................................[OK]"
}

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


##
# turn on the logging of isql statements 
function _trace_on(){
	run_cmd "trace_on('errors','exec');"
}

##
# start rdf_loaders
function start_loader(){
	for x in {1..5} ; do rdf_loader_run  ;   done
} 

##
# run the passed in command through the virtuoso isql interface
# params : isql command 
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
# update the facet
#
function update_facet(){
	echo "Updating facet browser. This could take awhile....."
 	
 	run_cmd "RDF_OBJ_FT_RULE_ADD(null,null,'All');"  logs/virtuoso_cmd.log
 	run_cmd "VT_INC_INDEX_DB_DBA_RDF_OBJ();"  logs/virtuoso_cmd.log
	echo "Done building index"
}

##
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