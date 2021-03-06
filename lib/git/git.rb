require_relative '../bash'
require_relative './commit'
require 'semantic'
require 'ostruct'
require 'date'

module Git
  def self.reset_repo(branch_name)
    # resets the repo to a clean state
    checkout(branch_name)
    fetch()
    Bash::exec("git reset --hard origin/#{branch_name}")
    Bash::exec("git clean -x -d -f")
  end

  def self.fetch
    Bash::exec("git fetch origin --prune --recurse-submodules -j9")
  end

  def self.exist?(path)
    current_branch = get_current_branch()
    # grep is case sensitive, which is what we want.  Piped to cat so the grep error code is ignored.
    "" != Bash::exec("git ls-tree --name-only -r #{current_branch} | grep ^#{path}$ | cat")
  end

  def self.all_files
    current_branch = get_current_branch()
    Bash::exec("git ls-tree --name-only -r #{current_branch}").split("\n")
  end

  def self.move(old_path, new_path)
    puts "Renaming #{old_path} to #{new_path}".yellow
    Bash::exec("git mv -f #{old_path} #{new_path}")
  end

  def self.add(files=nil)
    if files
      if files.is_a? Array
        files = files.join(' ')
      end
    else
      files = '.'
    end

    Bash::exec("git add #{files}")
  end

  def self.push_branch(branch_name)
    checkout(branch_name)
    fetch()
    # always merge to include any extra commits added during release process
    Bash::exec("git merge origin/#{branch_name} --no-edit")
    Bash::exec("git push origin #{branch_name}")
  end

  def self.push_tag(tag_name)
    Bash::exec("git push origin #{tag_name}")
  end

  def self.is_clean_git?
    Bash::exec("git status --porcelain").strip.empty?
  end

  def self.get_current_branch
    Bash::exec("git symbolic-ref --short HEAD").strip
  end

  def self.detached?
    Bash::exec("git symbolic-ref --short -q HEAD | cat").strip.empty?
  end

  def self.untracked_files
    Bash::exec("git ls-files --others --exclude-standard").strip
  end

  def self.diff
    Bash::exec("git diff")
  end

  def self.cached
    Bash::exec("git diff --cached")
  end

  def self.repo_url
    Bash::exec("git remote -v show | head -n1 | awk '{print $2}'").strip
  end

  def self.delete_branch(branch_name)
    if has_branch? branch_name
      Bash::exec("git branch -D #{branch_name}")
    end
  end

  def self.has_branch?(branch_name)
    !Bash::exec("git branch --list #{branch_name}").strip.empty?
  end

  def self.has_remote_branch?(branch_name)
    !Bash::exec("git branch --list -r #{branch_name}").strip.empty?
  end

  def self.checkout(branch_name)
    if get_current_branch != branch_name
      Bash::exec("git checkout #{branch_name}")
    end
  end

  def self.confirm_tag_overwrite(new_tag)
    tag_results = Bash::exec('git tag -l')
    tag_results.split.each do |existing_tag|
      if existing_tag == new_tag
        Printer.check_proceed("Tag #{existing_tag} already present. Overwrite tag #{existing_tag}?", "Tag #{existing_tag} not overwritten.")
      end
    end
  end

  def self.get_local_head_sha1
    rev_parse("head")
  end

  def self.get_local_branch_sha1(branch_name)
    rev_parse(branch_name)
  end

  def self.get_remote_branch_sha1(branch_name)
    rev_parse("origin/#{branch_name}")
  end

  def self.rev_parse(branch_name)
    output = Bash::exec("git rev-parse --verify #{branch_name} 2>&1 | cat").strip
    if output.include? 'fatal: Needed a single revision'
      puts "error: branch or commit '#{branch_name}' does not exist. You may need to checkout this branch.".red
      abort()
    end
    output
  end

  def self.is_ancestor?(root_branch, child_branch)
    "0" == Bash::exec("git merge-base --is-ancestor #{root_branch} #{child_branch}; echo $?").strip
  end

  def self.tag(new_tag, changelog)
    confirm_tag_overwrite(new_tag)
    puts "tagging with changelog: \n\n#{changelog}\n".yellow
    changelog_tempfile = Tempfile.new("#{new_tag}.changelog")
    changelog_tempfile.write(changelog)
    changelog_tempfile.close
    # include changelog in annotated tag
    Bash::exec("git tag -a -f #{new_tag} -F #{changelog_tempfile.path}")
    changelog_tempfile.unlink
  end

  def self.init_gh_pages
    if !has_branch? "gh-pages"
      if has_remote_branch? "origin/gh-pages"
        checkout("gh-pages")
      else
        Bash::exec("git checkout --orphan gh-pages")
        Bash::exec("find . | grep -ve '^\.\/\.git.*' | grep -ve '^\.$' | xargs git rm -rf")
        Bash::exec("touch README.md")
        Bash::exec("git add .")
        Bash::exec("git commit -am \"Initial gh-pages commit\"")
        if !repo_url.empty?
          Bash::exec("git push -u origin gh-pages")
        end
      end
    end
  end

  def self.tags(remote=false)
    if remote
      Bash::exec("git ls-remote --tags").split("\n")
        .map { |tag| tag.split()[1].strip.gsub("refs/tags/", "") }
        .keep_if { |tag| !tag.include? "{}" }
    else
      Bash::exec("git tag --list").split("\n")
    end
  end

  def self.tagged_versions(remote=false, raw_tags=false)
    version_reg = Semantic::Version::SemVerRegexp
    tags = self.tags(remote)

    tags.select { |tag|
      tag = tag[1..tag.size] if tag.start_with? "v"
      tag =~ version_reg
    }.map { |tag|
      if !raw_tags and tag.start_with? "v"
        tag = tag[1..tag.size]
      end
      tag
    }.compact
  end

  def self.commit(message)
    Bash::exec("git commit -m'#{message}'")
  end

  def self.reset_head(hard=false)
    Bash::exec("git reset#{' --hard' if hard} HEAD")
  end

  def self.commits(from_tag=nil, to_tag="HEAD")
    rev = ""
    if from_tag
      rev = "#{from_tag}..#{to_tag}"
    end

    # Format: [short hash] [date] [commit message] ([author])
    commits = Bash::exec("git log #{rev} --pretty=format:'%h %ad%x20%s%x20%x28%an%x29' --date=iso").split("\n").reverse!

    commits.map { |commit|
      spl = commit.split(' ')
      datestr = spl[1..3].join(' ')

      authorparts = []
      i = spl.count - 1
      authorpart = spl[i]

      loop do
        authorpart = spl[i]
        authorparts << authorpart

        i -= 1
        if authorpart.start_with? '('
          break
        end
      end

      author = authorparts.join(' ').gsub(/\(|\)/, '')
      msgstartidx = commit.index(datestr) + datestr.length
      message = commit[(commit.index(datestr) + datestr.length)..(commit.index('(' + author) - 1)].strip

      Commit.new(message, author, Date.iso8601(spl[1..2].join('T') + spl[3]), spl[0])
    }
  end
end
