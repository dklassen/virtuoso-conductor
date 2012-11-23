require 'yaml'
require 'pty'

namespace :ctd do
	
	desc "load the yaml configuration for the server instance"
	task :load_config do
		@config = YAML::load(File.open(File.expand_path(File.join(__FILE__,"../../../config/yaml_config/dataspace.yaml"))))
	end

	desc "generate the ctd rdf and put it in the data directory"
	task :generate => [:load_config] do

		files = ["chem_gene_ixns",
					"chem_gene_ixn_types",
					"chemicals_diseases",
					"chem_go_enriched",
					"chem_pathways_enriched",
					"genes_diseases",
					"genes_pathways",
					"diseases_pathways",
					"chemicals",
					"diseases",
					"genes",
					"pathways"]

		ctd_script_path = File.join(@config['script_dir'],"ctd")
		puts "using #{ctd_script_path}"	
		
		if File.exists? ctd_script_path
			Dir.chdir( ctd_script_path) do
			
				puts "Generate CTD RDF:"

				files.each do |file|
					PTY.spawn "php ctd.php files=#{file} indir=#{@config['download_dir']}/ctd/ outdir=#{@config['data_dir']}/ctd/ download=true" do |stdin,stdout,pid|
						stdin.each { |line| print line }
					end
				end

				puts "finished generating rdf"
			end
		else
		  puts "No script found: #{ctd_script_path}"
		  exit!
		end
	end
end
