require 'json'
require 'net/http'

require 'sinatra'
require 'neo4j'
require 'pry'

require './lib/corenlp_client'
require './lib/neo4j_client'
require './lib/frame'
require './lib/node'
require './lib/relation'
require './lib/points_extraction'
require './lib/utils'

set :port, ENV['PORT']
set :bind, '0.0.0.0'
set :public_folder, 'static'

corenlp_client = CoreNlpClient.new("http://corenlp_server:#{ENV['CNLP_PORT']}")
neo4j_client = Neo4jClient.new("http://neo4j:7474")

frames = JSON.parse(File.open('verbs.json', 'r').read)
frame_queries = Hash[*Dir.glob('frame_queries/*.cql').map do |path|
  [path.scan(/\/((\w|-)+)\./)[0][0].humanize.upcase.gsub('-COPULA', '-cop'),
    File.open(path, 'r').read]
end.flatten]

post '/' do
  data = JSON.parse(request.body.read)

  points = []
  Utils.chunk_text(35000, Utils.clean_text(data["text"])).each do |text|
    neo4j_client.clear
    sentences = corenlp_client.request_parse(text)
    sentences.select! { |s| Utils.sentence_contains_topic(s, data['topics']) }
    next if sentences.empty?
    begin
      puts sentences.size
      sentences.each_slice(5).each do |group|
        query_string = neo4j_client.generate_create_query_for_sentences(group)
        neo4j_client.execute(query_string)
      end
      matches = PointsExtraction.matches_for_verbs(neo4j_client, frames, frame_queries)
      points += PointsExtraction.points_for_matches(neo4j_client, matches, data['topics'], data['keys'])
        .uniq
        .sort_by(&:size)
    rescue Exception => ex
      puts ex
      return points.to_json
    end
  end

  points.to_json
end
