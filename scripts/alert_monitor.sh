function _report(){
	if [[ ! $report_address ]]; then
		echo "unable to report no report_address was set"
		exit 1
	fi
	
	echo $1 | mail virtuoso-error $report_address
}