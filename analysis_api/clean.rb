require 'json'

unless ARGV[0]
  puts "missing corpus argument"
  puts "try: ruby clean.rb abortion"
  exit
end

Dir.glob("#{ARGV[0]}/*").to_a.each do |file, index|
  puts file
  if file.include? "json"
    `rm #{file}`
    next
  end
  content = File.open(file).read
  content = content.chars.select(&:valid_encoding?).join

  meta = Hash[*content.scan(/^#.*=.*$/).map { |e| e.delete('#').split("=") }.flatten]
  meta = meta.inject({}){ |memo,(k,v)| memo[k.to_sym] = v; memo }.merge!(post: file.gsub(/[^0-9]/, ''))

  content = content
    .gsub(/^#.*=.*$/, "")
    .gsub(/\[[0-9]+\]/, "")
    .gsub(/http\S+|\S{30,}/, "")
    .gsub(/([a-z]{3,}\.)([A-Z][a-z]{3,})/, '\1 \2')
    .gsub(/([a-z]{3,}\.)([0-9]\.)/, '\1 \2')
    .gsub(/\s+/, " ")
    .gsub("[...]", "")
    .gsub("/>", "")
    .gsub(" / ", "")
    .strip
  processed_file = meta.merge(content: content)
  File.open("#{file}.json", "w").write(processed_file.to_json)
end