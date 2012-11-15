# !bin/bash -x

# require the necessary files
source config/config.cfg
source scripts/alert_monitor.sh
source lib/virtuoso_proxy_functions.sh
source lib/utils.sh


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
while getopts "rt:n:" opt; do
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
      e)
			echo "setting notification to $OPTARG"
			report_address=$OPTARG
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
	setup)
		if [ ! $2 ]; then
			echo "Need to specify a instance to load. Use [list] to show."
			exit 1
		fi

		_setup_instance $2
		exit 0
		;;
	start)
		if [ ! $2 ]; then
			echo "Need to specify a instance to load. Use [list] to show."
			exit 1
		fi

		 _load_instance $2

		 if [[ $? == 0 ]]; then
		 	start
		 else
		 	exit 1
		 fi
	;;
	stop)
		if [ ! $2 ]; then
			echo "Need to specify a instance to load. Use [list] to show."
			exit 1
		fi

		 _load_instance $2

		 if [[ $? == 0 ]]; then
		 	stop
		 else
		 	exit 1
		 fi
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
	info)
		if [ ! ${2} ]; then
			echo "supply the name of an instance"
			_list_instances
			exit 0
		fi

		_instance_info $2
		exit 0
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

			if [[ ! $5 ]]; then
				echo "specify an instance to use"
				_list_instances
			fi

			_load_instance $5

			if [[ $? == 1 ]]; then
				exit 1
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
	list)
		_list_instances
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


