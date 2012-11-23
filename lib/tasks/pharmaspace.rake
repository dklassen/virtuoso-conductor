require 'yaml'
namespace :dataspace do 
	desc "load the YAML configuration file"
	task :load_yaml do
		@dataspace = YAML::load(File.open(File.expand_path(File.join(__FILE__,"../../../config/yaml_config/pharmaspace.yaml"))))	
	end

	desc "provide some information about the dataspace being load"
	task :info => [:load_yaml] do
		puts "dataspace name: " + @dataspace['dataspace']
		puts " data directory: " + @dataspace['data_dir']
		puts " virtuoso_dir: " + @dataspace['virtuoso_dir']
		puts " script_dir: " + @dataspace['script_dir']
	 
	end

	desc "generate the RDF from the CTD"
	task :generate_ctd => [:load_yaml] do
 		ctd_script = "@datapspace['script_dir']/ctd/ctd.php"		
	end


end
