# script to generate statistics about virtuoso machine and report back periodically about usage
# we can use lsof to look at the port number being used by the virtuoso
# db_status() and parse the information from the string
# select * from load_list where ll_state = 0  // files that have not been loaded yet
# select * from load_list where ll_state = 1 // number of currently 
# select * from load_list where ll_error is not null // errors
# select * from load_list where ll_state = 2 and ll_error is not null // completed without error