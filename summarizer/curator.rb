require 'net/http'

module Curator
  class CoreNLPClient
    def initialize(host)
      params = URI.encode('properties={"annotators": "lemma,tokenize,ssplit,depparse"}')

      @uri = URI(host + "/?" + params)
      @http_client = Net::HTTP.new(@uri.host, @uri.port)
    end

    def request_parse(text)
      req = Net::HTTP::Post.new(@uri)
      req.body = text
      JSON.parse(@http_client.request(req).body)['sentences'].map do |sentence|
        [sentence['tokens'], sentence['collapsed-ccprocessed-dependencies']]
      end
    end
  end

  def self.select_best(points)
    cnc = CoreNLPClient.new("http://local.docker:9000")

    points.uniq! { |p| p["String"] }

    points.each do |point|
      parse = cnc.request_parse(clean_string(point["String"])).first
      point["Relations"], point["Lemmas"] = relations_and_lemmas_from_parse(parse)
    end

    top_point = points.reject do |point|
      !point["String"].length.between?(25, 100) ||
      point["String"].include?("this") ||
      point["String"].include?("And") ||
      point["String"].scan(/[a-z]+[0-9A-Z]/).size > 0 ||
      point["Relations"].include?("advcl") ||
      point["Relations"].include?("dep") ||
      point["String"].scan(/[LR]RB|[LR]SB/).size.odd? ||
      point["String"].match(/^\w+ ?, /) ||
      point["String"].gsub(" ", "").match(/,{2,}/) ||
      point["String"].match(/([A-Z]+ ){2,}/) ||
      point["String"].match(/^(if|and|but|or|just|after|before|their|his|her|why)/i) ||
      point["Relations"].count { |r| r.match(/acl|csubj|ccomp/) } > 0 ||
      point["Relations"].count { |r| r.match(/conj|nmod|acl/) } > 2 ||
      contains_case_change(point)
    end.sort_by { |p| p["String"].length }.last
  end

  def self.clean_string(string)
    string = string.strip
      .gsub(/^\W+/, "")
      .gsub(/ ?- ?\.?$/, "")
      .gsub(/[\s;\.,]+$/, "")
      .gsub(/\s+(n?[,'\.])/, '\1')
      .gsub("-LRB-", "(").gsub("-RRB-", ")")
      .gsub("( ", "(").gsub(" )", ")")
      .gsub("-LSB-", "[").gsub("-RSB-", "]")
      .gsub("[ ", "[").gsub(" ]", "]").strip
      .gsub("` ", "'")
    string.gsub!(/^(then|than|so|to|when|what|that|if|of|even|about|because)\s/i, "")
    string = "#{string[0].upcase}#{string[1..-1]}"
    string.gsub!(/[;.]+/, "")
    string.gsub!(/ [:\-]$/, "")
    string.gsub!(" ,", "")
    string = string.strip
    string += "." if string.strip[-1] != "."
    string
  end

  def self.relations_and_lemmas_from_parse(parse)
    relations = parse.last.group_by { |r| r["dependent"] }
      .map { |k, v| [k-1, v.map { |r| r["dep"] }] }
      .sort_by { |index, _| index }
      .map(&:last).map { |r| r.join("|") }
    return relations, parse.first.map { |t| t["lemma"] + ":" + t["originalText"] + ":" + t["pos"] }
  end

  def self.contains_case_change(point)
    return false unless point["String"].match(/\s[A-Z]/)
    point["Lemmas"].count do |e|
      next unless e.match(/\w/) && point["Lemmas"].index(e) > 0
      e = e.split(":")
      e[1].match(/^[A-Z]/) && !e[2].match(/^NN|^PRP/) && e[1].upcase != e[1]
    end > 0
  end
end
