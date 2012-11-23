require 'yaml'
namespace :ctd do
	
	desc "load the yaml configuration for the server instance"
	task :load_config do
		@config = YAML::load(File.open(File.expand_path(File.join(__FILE__,"../../../config/yaml_config/dataspace.yaml"))))
	end

	desc "generate the ctd rdf and put it in the data directory"
	task :generate => [:load_config] do
		ctd_script_path = File.join(@config['script_dir'],"ctd")
		puts "using #{ctd_script_path}"	
		
		if File.exists? ctd_script_path
			Dir.chdir( ctd_script_path) do
			
				puts "Generate CTD RDF:"
				IO.popen("php ctd.php files=all indir=#{@config['download_dir']}/ctd/ outdir=#{@config['data_dir']}/ctd/ download=true") {|f| puts f.gets}
				puts "finished generating rdf"
			end
		else
		  puts "No script found: #{ctd_script_path}"
		  exit!
		end
	end
end
