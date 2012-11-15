##
# print the help messages for use

function _usage(){
 cat <<"USAGE"
	
	select from one of the following options:
	[list|setup|start|stop|restart|load|clear|index|destory]

	setup   : create the symlinks needed to run the virtuoso instance
	list    : list the available instances to interact with
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
# list all the configured instances 
function _list_instances(){
	echo "List of available instances:"
	#declare -a files
	_get_instances files

	for instance in "${files[@]}"
	do
		echo  ` grep instance_name= ${instance} | sed 's/instance_name="\(.*\)"/\1/'` 
	done
}

# Check if a value exists in an array
# @param $1 mixed  Needle  
# @param $2 array  Haystack
# @return  Success (0) if value exists, Failure (1) otherwise
# Usage: in_array "$needle" "${haystack[@]}"
# See: http://fvue.nl/wiki/Bash:_Check_if_array_element_exists
in_array() {
    local hay needle=$1
    shift
    for hay; do
        [[ $hay == $needle ]] && echo true && return 0
    done
    echo false && return 1
}

##
# get the instance_name of each config file in the directory
function _get_instance_names(){
	local _instance_names=$1

	DIR="${PWD}/config/virtuoso_instances/"
	local _instance_files=($(find $DIR -type f))

	for (( i = 0 ; i < ${#_instance_files[@]} ; i++ ))
	do
		_instance_files[i]=`grep instance_name\= ${_instance_files[i]} | sed 's/instance_name="\(.*\)"/\1/'`
	done

	eval "$_instance_names=(\"\${_instance_files[@]}\")"
}

##
# print the info of the passed in instance_name
function _instance_info(){
	_load_instance $1

	if [[ $? == 1 ]];then
		echo "incorrect instance supplied choose one from below:"
		_list_instances
		exit 1
	fi

	status check
	echo "Settings:"
cat <<EOF
	name: $instance_name
	install_dir: $location
	isql_port: $isql_port
	http_server: $http_server
	status: $check
EOF
}


function _setup_instance(){
	_load_instance $1
	if [ ! -f $virtuoso ]; then
		ln -s $virtuoso_home/bin/virtuoso-t $virtuoso

		if [[ $? == 1 ]]; then
			return 0
		else
			return 1
		fi
	fi

	echo "setup........................... [ complete ]" && return 0
}

##
# return an array of instances
function _get_instances(){
	local _virtuoso_instances=$1
	
	# save and change IFS 
	OLDIFS=$IFS
	IFS=$'\n'

	DIR="${PWD}/config/virtuoso_instances/"
	# read all file name into an array
	local _virtuoso_instances_list=($(find $DIR -type f))

	# restore it 
	IFS=$OLDIFS

	eval "$_virtuoso_instances=(\"\${_virtuoso_instances_list[@]}\")"
}

##
# load the configuation file of an instance 
# param : instance_name, the name of the instance we want to get the configuration file for
function _load_instance(){
	
	_get_instance_names instances
	
	if [ $(in_array $1 "${instances[@]}") ]; then

		_get_instances instances
		for instance in "${instances[@]}"
		do
			
			instance_name=`grep instance_name= ${instance} | sed 's/instance_name="\(.*\)"/\1/'`

			if [[ $instance_name = $1 ]]; then
				echo "Loading: $1" && source $instance && return 0
			fi
		done
	fi

	return 1

}

##
# check for errors while running isql commands on the server
# param : pid of the logfile being monitored
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

##
# place all the checks that need to be done here
function system_check(){
	if [ ! $virtuoso_home ]; then echo "virtuoso_home is not configured. Please set VIRTUOSO_HOME in your .bash_profile"; exit 1; fi
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