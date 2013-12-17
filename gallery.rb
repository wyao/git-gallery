require 'git'
require 'json'
require 'optparse'
require 'ostruct'
require 'set'

# Default options
opts = OpenStruct.new
opts.author = ''
opts.level = 2
opts.until = 0

# Parse options
OptionParser.new do |options|
  options.banner = "ruby gallery.rb --author 'Willie Yao' --level 1 --repo ~/airbnb/airbnb --type sankey --since 20"

  options.on('--author=', String, 'Commit author (default all)') do |opt|
    opts.author = opt
  end
  options.on('--level=', Integer, 'Depth of subfolders to visualize (default 2)') do |opt|
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
  paths = Set.new
  links = []
  nodes = []
  commits = Set.new

  opts.repos.each do |repo|
    g = Git.open(repo)
    (opts.until..opts.since).each do |week|
      buckets = {}
      has_activity = false
      g.log.author(opts.author).since("#{week+1} weeks ago").until("#{week} weeks ago").each do |l|
        l.diff_parent.stats[:files].each do |file, diffs|
          # Fold all files into their containing folder
          folded_path = file.split('/')
          folded_path = folded_path.take(folded_path.size - 1)
          # Fold paths according to the specified level
          folded_path = folded_path[0..opts.level].join('/')
          sum = diffs[:insertions] + diffs[:deletions]
          sum += buckets[folded_path] if buckets.has_key?(folded_path)
          buckets[folded_path] = sum
        end
      end
      buckets.each do |path,diff|
        paths.add(path)
        links << { :source => "T -#{week} weeks", :target => path, :value => diff.to_s }
        # Only add commit if there was activity
        commits.add("T -#{week} weeks")
      end
    end

    paths.each do |path|
      nodes << { :name => path }
    end
  end

  # Convert nodes into list of hashes
  commits.each do |node|
    puts node
    nodes << { :name => node }
  end

  data = {}
  data[:links] = links
  data[:nodes] = nodes

  File.open('data/sankey.json', 'w+') do |f|
    f.write(data.to_json)
  end
  exec('open /Applications/Google\ Chrome.app/ clients/sankey.html --args --allow-file-access-from-files')
end
