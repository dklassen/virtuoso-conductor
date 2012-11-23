require 'mechanize'
#require 'net/ftp'

##
# rake tasks to check data source freshness with data currently loaded in the endpoints

namespace :ctd do
	desc "Check if the comparative toxicogenomics database needs to be updated"
	task :status do
		datasets             = {"chemical-genes" =>	"//div[@id=\"cg\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"chemical-gene-interactions-types"       => "//div[@id=\"gcixntypes\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"chemical-disease-associations"          =>	"//div[@id=\"cd\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"chemical-pathway-enriched-associations" =>	"//div[@id=\"chempathwaysenriched\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"chemical-go-enriched-assocations"       =>	"//div[@id=\"chemgoenriched\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"gene-pathways-associations"             => "//div[@id=\"genepathways\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"disease-pathway-assocations"            => "//div[@id=\"diseasepathways\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"chemical-vocabulary"                    => "//div[@id=\"allchems\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"disease-vocabulary"                     =>	"//div[@id=\"alldiseases\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"gene-vocabulary"                        =>	"//div[@id=\"allgenes\"]/table[@class=\"filelisting\"]/tr/td/text()",
		"pathway-vocabulary"                     =>	"//div[@id=\"allpathways\"]/table[@class=\"filelisting\"]/tr/td/text()"}
		status_agent = Mechanize.new
		status_page = status_agent.get("http://ctdbase.org/downloads/")

		dates = Hash.new
		datasets.each_pair do |dataset,path|
			#dates.store(dataset, status_page.parser.xpath(path).first.to_s)
			puts "#{dataset} : #{ status_page.parser.xpath(path).first.to_s}"
		end
		
	end
end

namespace :omim do
	desc "check Online inheritance in man for update status"
	task :status => :environment do

		status_agent = Mechanize.new
		status_page = status_agent.get("http://omim.org/statistics/entry")

		date  = Date.parse(status_page.parser.xpath("//span[@class=\"statistics-date\"]/text()").to_s.gsub("[()]","").gsub("Updated",""))
		

		puts date
	end
end

=begin
namespace :gene do
	desc "check NCBI gene update status"
	task :status do
			datafiles = [ 
							"gene2accession.gz",
							"gene2ensembl.gz",
							"gene2go.gzs",
							"gene2pubmed.gz",
							"gene2refseq.gz",
							"gene2sts",
							"gene2unigene",
							"gene2vega.gz",
							"gene_group.gz",
							"gene_history.gz",
							"gene_info.gz",
							"gene_refseq_uniprotkb_collab.gz"
						]

		#files = system("curl ftp://ftp.ncbi.nih.gov/gene/DATA/") 
		#puts files

	end
end
=end
