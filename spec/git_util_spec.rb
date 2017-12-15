require 'fileutils'
require_relative '../lib/git_util'
require_relative '../lib/command_processor'
include Releasinator

describe GitUtil do

  def create_local_repo
    dir = Dir.mktmpdir
    Dir.chdir dir

    CommandProcessor.command("git init")
    CommandProcessor.command("git config user.name 'test'")
    CommandProcessor.command("git config user.email 'test@example.com'")

    CommandProcessor.command("touch init.ini")
    CommandProcessor.command("git add -A")
    CommandProcessor.command("git commit -m'initial commit'")

    dir
  end

  before(:each) do
    @wd = Dir.pwd
    @dir = create_local_repo
  end

  after(:each) do
    FileUtils.remove_dir(@dir)
    Dir.chdir @wd
  end

  describe 'exist?' do
    it 'does exist' do
      CommandProcessor.command("echo 'hello' > hello_world.rb")
      CommandProcessor.command("git add -A")
      CommandProcessor.command("git commit -m'ic'")

      expect(GitUtil.exist?('hello_world.rb')).to be true
    end

    it 'doesnt exist' do
      expect(GitUtil.exist?('hello_world.rb')).to be false
    end
  end

  describe 'all files' do
    it 'returns all files' do
      CommandProcessor.command("echo 'hello' > hello_world.rb")
      CommandProcessor.command("echo 'hello' > hello_world_2.rb")
      CommandProcessor.command("git add -A")
      CommandProcessor.command("git commit -m'ic'")

      all_files = GitUtil.all_files
      expect(all_files.count).to eq 3
      expect(all_files).to include 'hello_world.rb'
      expect(all_files).to include 'hello_world_2.rb'
    end
  end

  describe 'checkout' do
    it 'checks out other branch' do
      CommandProcessor.command("git checkout -b new-branch")
      expect(CommandProcessor.command("git symbolic-ref --short HEAD").strip).to eq "new-branch"

      GitUtil.checkout("master")
      expect(CommandProcessor.command("git symbolic-ref --short HEAD").strip).to include "master"
    end
  end

  describe 'tag' do
    it 'creates tag with annotation' do
      GitUtil.tag('0.0.1', 'annotation')

      tags = CommandProcessor.command('git tag -n9')

      expect(tags).to include('0.0.1')
      expect(tags).to include('annotation')
    end
  end

  describe 'has_branch?' do
    it 'returns true when branch exists' do
      expect(GitUtil.has_branch?("master")).to be true
    end

    it 'returns false when branch doesnt exist' do
      expect(GitUtil.has_branch?("some-other-branch")).to be false
    end
  end

  describe 'has_remote_branch?' do
    it 'returns false when no remote branch' do
      expect(GitUtil.has_remote_branch?('some-nonexistent-remote-branch')).to be false
    end
  end

  describe 'init_gh_pages' do
    before(:each) do
      GitUtil.init_gh_pages
    end

    it 'creates gh-pages branch if not exist' do
      expect(CommandProcessor.command("git symbolic-ref --short HEAD").strip).to include "gh-pages"
    end

    it 'creates readme' do
      expect(File.exist?('./README.md')).to be true
    end

    it 'creates intial commit' do
      expect(CommandProcessor.command('git log --pretty=format:"%h %ad%x20%s%x20%x28%an%x29" --date=short')).to include 'Initial gh-pages commit'
    end
  end

  describe 'tags' do
    it 'lists local tags' do
      CommandProcessor.command("git tag '1.2.3'")
      CommandProcessor.command("git tag '1.2.4'")

      expect(GitUtil.tags).to eq(['1.2.3', '1.2.4'])
    end
  end

  describe 'tagged_versions' do
    it 'returns tagged versions' do
      CommandProcessor.command("git tag '1.2.3'")
      CommandProcessor.command("git tag 'v1.2.4'")
      CommandProcessor.command("git tag 'not-a-version'")

      expect(GitUtil.tagged_versions).to eq(['1.2.3', '1.2.4'])
    end
  end

  describe 'add' do
    it 'adds all files if no args present' do
      CommandProcessor.command("echo 'some code' > code.rb")
      CommandProcessor.command("echo 'some more code' > more_code.rb")

      GitUtil.add

      staged_file_count = CommandProcessor.command("git status -s | wc -l").strip.to_i

      expect(staged_file_count).to eq 2
    end

    it 'only adds files provided' do
      CommandProcessor.command("echo 'some code' > code.rb")
      CommandProcessor.command("echo 'some more code' > more_code.rb")

      GitUtil.add('code.rb')

      staged_file_count = CommandProcessor.command("git status -s | grep 'A' | wc -l").strip.to_i

      expect(staged_file_count).to eq 1
    end
  end

  describe 'commits' do
    it 'fetches all commits in chronological order' do
      CommandProcessor.command('touch new.txt')
      GitUtil.stage
      GitUtil.commit 'add new.txt'

      expect(GitUtil.commits.count).to eq 2

      commits = GitUtil.commits
      expect(commits[0].hash).not_to be nil
      expect(commits[0].message).to eq 'initial commit'
      expect(commits[0].date).not_to be nil
      expect(commits[0].author).to eq 'test'

      expect(commits[1].hash).not_to be nil
      expect(commits[1].message).to eq 'add new.txt'
      expect(commits[1].date).not_to be nil
      expect(commits[1].author).to eq 'test'
    end

    it 'fetches all commits in chronological order' do
      CommandProcessor.command('git tag start')

      CommandProcessor.command('touch new.txt')
      GitUtil.stage
      GitUtil.commit 'add new.txt'

      CommandProcessor.command('git tag finish')

      CommandProcessor.command('touch anothernew.txt')
      GitUtil.stage
      GitUtil.commit 'add anothernew.txt'

      commits = GitUtil.commits('start', 'finish')

      expect(commits.count).to eq 1

      expect(commits[0].hash).not_to be nil
      expect(commits[0].message).to eq 'add new.txt'
      expect(commits[0].date).not_to be nil
      expect(commits[0].author).to eq 'test'
    end
  end

  describe 'commit' do
    it 'commits with the correct message' do
      CommandProcessor.command('touch new.txt')
      GitUtil.stage
      GitUtil.commit 'add new.txt'

      expect(CommandProcessor.command("git log --pretty=format:'%h %ad%x20%s%x20%x28%an%x29' --date=short | head -n1")).to include "add new.txt"
    end
  end

  describe 'stage' do
    it 'stages all changed files when no files passed' do
      CommandProcessor.command('touch new.txt')

      staged_file_count = CommandProcessor.command("git status -s | grep 'A' | wc -l").strip.to_i
      untracked_file_count = CommandProcessor.command("git status -s | grep '??' | wc -l").strip.to_i

      expect(staged_file_count).to eq 0
      expect(untracked_file_count).to eq 1

      GitUtil.stage

      staged_file_count = CommandProcessor.command("git status -s | grep 'A' | wc -l").strip.to_i
      untracked_file_count = CommandProcessor.command("git status -s | grep '??' | wc -l").strip.to_i

      expect(staged_file_count).to eq 1
      expect(untracked_file_count).to eq 0
    end

    it 'stages files passed' do
      CommandProcessor.command('touch new.txt')
      CommandProcessor.command('touch new_untracked.txt')

      expect(CommandProcessor.command("git status -s | grep '??' | wc -l").strip.to_i).to eq 2

      GitUtil.stage "new.txt"

      expect(CommandProcessor.command("git status -s | grep '??' | wc -l").strip.to_i).to eq 1
      expect(CommandProcessor.command("git status -s | grep 'A' | wc -l").strip.to_i).to eq 1
    end
  end
end
