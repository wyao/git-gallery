require 'git' # TODO: Deprecate git in favor of grit
require 'grit'
require 'json'
require 'optparse'
require 'ostruct'
require 'set'

AIRBNB_DIR = '/Users/wyao/airbnb/airbnb/'

# Default options
opts = OpenStruct.new
opts.author = ''
opts.level = 2
opts.until = 0

# Parse options
OptionParser.new do |options|
  options.banner = "ruby gallery.rb --author 'Willie Yao' --level 1 --repo ~/airbnb/airbnb,~/airbnb/hopscotch,~/airbnb/chef --type sankey --since 20"

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
  node_set = Set.new

  opts.repos.each do |repo|
    g = Git.open(repo)
    (opts.until..opts.since).each do |week|
      buckets = {}
      has_activity = false
      g.log.author(opts.author).since("#{week+1} weeks ago").until("#{week} weeks ago").each do |l|
        begin
          l.diff_parent.stats[:files].each do |file, diffs|
            # Fold all files into their containing folder
            folded_path = file.split('/')
            folded_path = folded_path.take(folded_path.size - 1)
            # Fold paths according to the specified level and prepend repo
            folded_path = ([repo.split('/')[-1]] << folded_path[0..opts.level]).join('/')
            sum = diffs[:insertions] + diffs[:deletions]
            if sum > 0
              sum += buckets[folded_path] if buckets.has_key?(folded_path)
              buckets[folded_path] = sum
            end
          end
        rescue => e
          # Do nothing
        end
      end
      buckets.each do |path,diff|
        paths.add(path)
        links << { :source => "T -#{week} weeks", :target => path, :value => diff.to_s }
        # Only add commit if there was activity
        node_set.add("T -#{week} weeks")
      end
    end

    paths.each do |path|
      node_set.add(path)
    end
  end

  # Convert nodes into list of hashes
  nodes = []
  node_set.each do |node|
    nodes << { :name => node }
  end

  data = {}
  data[:links] = links
  data[:nodes] = nodes

  File.open('data/sankey.json', 'w+') do |f|
    f.write(data.to_json)
  end
  exec('open /Applications/Google\ Chrome.app/ clients/sankey.html --args --allow-file-access-from-files')
when 'sunburst'
  File.open('data/sunburst.csv', 'w+') do |f|
    Dir.glob("#{opts.repos[0]}/**/*.{java,rb,erb,rake,css,json}") do |file|
      lines, file_name = `#{"wc -l #{file}"}`.split(' ')
      file_name.sub!(opts.repos[0]+'/', '')
      file_name.gsub!('-', '_')
      file_name.gsub!('/', '-')
      # Output to csv
      f.puts "#{file_name},#{lines}"
    end
  end
  exec('open /Applications/Google\ Chrome.app/ clients/sunburst.html --args --allow-file-access-from-files')
when 'journal'
  START_YEAR = 2008
  END_YEAR = 2014

  # Change to root git directory (necessary for grit blame to work properly)
  pwd = Dir.pwd
  Dir.chdir AIRBNB_DIR

  age = []
  g = Grit::Repo.new(AIRBNB_DIR)

  Dir.glob("#{opts.repos[0]}/**/*.{rb}") do |file|
    buckets = {}
    (START_YEAR..END_YEAR).each do |year|
      buckets[year] = 0
      buckets[year + 0.25] = 0
      buckets[year + 0.5] = 0
      buckets[year + 0.75] = 0
    end

    # Process git blame
    blames = g.blame(file).lines
    blames.each do |blame|
      # Mathy stuff to split into 4 buckets per year
      partial = ((blame.commit.committed_date.month - 2) / 3.0).round / 4.0
      partial = 0 if partial == 0
      buckets[blame.commit.committed_date.year + partial] += 1
    end

    entry = {}
    entry['name'] = file.sub(opts.repos[0], '')
    entry['total'] = blames.size
    entry['articles'] = []

    buckets.each do |year, count|
      entry['articles'] << [year, count] if count > 0
    end

    age << entry
  end

  # Sort
  age.sort_by! do |entry|
    score = 0
    entry['articles'].each do |bucket|
      score -= bucket[1] * (END_YEAR - bucket[0])
    end
    score
  end

  # Output to file
  File.open("#{pwd}/data/journal.json", 'w+') do |f|
    f.write(age.to_json)
  end

  exec("open /Applications/Google\\ Chrome.app/ #{pwd}/clients/journal.html --args --allow-file-access-from-files")
end
