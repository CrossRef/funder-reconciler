require 'bundler/setup'
require 'sinatra'
require 'json'
require 'open-uri'

set :bind, '0.0.0.0'

helpers do
	def search_funders test_funder_name
		uri ="http://api.crossref.org/funders?query=#{URI::encode(test_funder_name)}" 
		res = open(uri).read
		return  JSON.parse(res)
	end
end

get '/heartbeat/?' , :provides => [:html, :json] do
	status = {:status => "OK",  :pid => "#{$$}", :ruby_version => "#{RUBY_VERSION}", :phusion => defined?(PhusionPassenger) ? true : false }
	status.to_json
end

post '/reconcile/?' , :provides => [:html, :json] do
	content_type :json
	queries = JSON.parse params['queries']
	return {}.to_json unless queries['q0'].has_key?('type')
	results = {}
	queries.each_pair do |key,q|
		hits = search_funders(q['query'])
		results[key]=Hash.new
		results[key]['result'] = Array.new
		score = 0;
		type = {"id" => "/fundref/funder", "name" => "Funder"}
		hits['message']['items'].each do |hit|
			doi = "http://dx.doi.org/10.13039/#{hit['id']}"
			entry = {"id" => doi, "name"=>hit["name"], "type" => [type], "score"=> score, "match" => "false", "uri" => doi}
			results[key]['result'].push(entry)
			score =+ 1
		end
	end
	results.to_json
end

get '/reconcile/?' , :provides => [:html, :json] do
	callback = params['callback']
	default_types = [{"id"=>"/fundref/funder_name", "name"=>"Open Funder ID"}]
	r = {"name" => "Open Funder Registry Reconciliation Service",  "identifierSpace" => "http://openfunder.crossref.org/openfunder", "schemaSpace" => "http://openfunder.crossref.org/ns/type.object.id", "defaultTypes" => default_types}
	content_type :js
	p = JSON.pretty_generate(r)
	"#{callback}(#{p})"
end

