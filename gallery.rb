require 'git'
require 'json'
require 'optparse'
require 'ostruct'
require 'set'

# Default options
opts = OpenStruct.new
opts.author = ''
opts.level = 0
opts.until = 0

# Parse options
OptionParser.new do |options|
  options.banner = "ruby gallery.rb --author 'Willie Yao' --level 1 --repo ~/airbnb/airbnb --type sankey --since 20"

  options.on('--author=', String, 'Commit author (default all)') do |opt|
    opts.author = opt
  end
  options.on('--level=', Integer, 'Number of path levels to compress (default 0)') do |opt|
    opts.level = opt
  end
  options.on('--repos=', Array, 'Git repos to process') do |opt|
    opts.repos = opt
  end
  options.on('--since=', Integer, 'Weeks since') do |opt|
    opts.since = opt
  end
  options.on('--type=', String, 'Type of gallery') do |opt|
    opts.type = opt
  end
  options.on('--until=', Integer, 'Weeks until (default 0)') do |opt|
    opts.until = opt
  end
end.parse!

puts opts

case opts.type
when 'sankey'
  g = Git.open(opts.repos[0])

  paths = Set.new
  links = []
  nodes = []

  (opts.until..opts.since).each do |week|
    buckets = {}
    has_activity = false
    g.log.author(opts.author).since("#{week+1} weeks ago").until("#{week} weeks ago").each do |l|
      l.diff_parent.stats[:files].each do |file, diffs|
        folded_path = file.split('/')[0..(-1 * opts.level - 1)].join('/')
        sum = diffs[:insertions] + diffs[:deletions]
        sum += buckets[folded_path] if buckets.has_key?(folded_path)
        buckets[folded_path] = sum
      end
    end
    buckets.each do |path,diff|
      paths.add(path)
      links << {:source => "T -#{week} weeks", :target => path, :value => diff.to_s}
      has_activity = true
    end
    if has_activity
      nodes << { :name => "T -#{week} weeks" }
    end
  end

  paths.each do |path|
    nodes << { :name => path }
  end

  data = {}
  data[:links] = links
  data[:nodes] = nodes

  File.open('data/sankey.json', 'w+') do |f|
    f.write(data.to_json)
  end
  exec('open /Applications/Google\ Chrome.app/ clients/sankey.html --args --allow-file-access-from-files')
end
