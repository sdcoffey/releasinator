require 'fileutils'
require_relative '../../lib/git/git'
require_relative '../../lib/bash'

include Releasinator

describe Git do

  def create_local_repo
    dir = Dir.mktmpdir
    Dir.chdir dir

    Bash::exec("git init")
    Bash::exec("git config user.name 'test'")
    Bash::exec("git config user.email 'test@example.com'")

    Bash::exec("touch init.ini")
    Bash::exec("git add -A")
    Bash::exec("git commit -m'initial commit'")

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
      Bash::exec("echo 'hello' > hello_world.rb")
      Bash::exec("git add -A")
      Bash::exec("git commit -m'ic'")

      expect(Git::exist?('hello_world.rb')).to be true
    end

    it 'doesnt exist' do
      expect(Git::exist?('hello_world.rb')).to be false
    end
  end

  describe 'all files' do
    it 'returns all files' do
      Bash::exec("echo 'hello' > hello_world.rb")
      Bash::exec("echo 'hello' > hello_world_2.rb")
      Bash::exec("git add -A")
      Bash::exec("git commit -m'ic'")

      all_files = Git::all_files
      expect(all_files.count).to eq 3
      expect(all_files).to include 'hello_world.rb'
      expect(all_files).to include 'hello_world_2.rb'
    end
  end

  describe 'checkout' do
    it 'checks out other branch' do
      Bash::exec("git checkout -b new-branch")
      expect(Bash::exec("git symbolic-ref --short HEAD").strip).to eq "new-branch"

      Git::checkout("master")
      expect(Bash::exec("git symbolic-ref --short HEAD").strip).to include "master"
    end
  end

  describe 'tag' do
    it 'creates tag with annotation' do
      Git::tag('0.0.1', 'annotation')

      tags = Bash::exec('git tag -n9')

      expect(tags).to include('0.0.1')
      expect(tags).to include('annotation')
    end
  end

  describe 'has_branch?' do
    it 'returns true when branch exists' do
      expect(Git::has_branch?("master")).to be true
    end

    it 'returns false when branch doesnt exist' do
      expect(Git::has_branch?("some-other-branch")).to be false
    end
  end

  describe 'has_remote_branch?' do
    it 'returns false when no remote branch' do
      expect(Git::has_remote_branch?('some-nonexistent-remote-branch')).to be false
    end
  end

  describe 'init_gh_pages' do
    before(:each) do
      Git::init_gh_pages
    end

    it 'creates gh-pages branch if not exist' do
      expect(Bash::exec("git symbolic-ref --short HEAD").strip).to include "gh-pages"
    end

    it 'creates readme' do
      expect(File.exist?('./README.md')).to be true
    end

    it 'creates intial commit' do
      expect(Bash::exec('git log --pretty=format:"%h %ad%x20%s%x20%x28%an%x29" --date=short')).to include 'Initial gh-pages commit'
    end
  end

  describe 'tags' do
    it 'lists local tags' do
      Bash::exec("git tag '1.2.3'")
      Bash::exec("git tag '1.2.4'")

      expect(Git::tags).to eq(['1.2.3', '1.2.4'])
    end
  end

  describe 'tagged_versions' do
    it 'returns tagged versions' do
      Bash::exec("git tag '1.2.3'")
      Bash::exec("git tag 'v1.2.4'")
      Bash::exec("git tag 'not-a-version'")

      expect(Git::tagged_versions).to eq(['1.2.3', '1.2.4'])
    end
  end

  describe 'commits' do
    it 'fetches all commits in chronological order' do
      Bash::exec('touch new.txt')
      Git::add
      Git::commit 'add new.txt'

      expect(Git::commits.count).to eq 2

      commits = Git::commits
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
      Bash::exec('git tag start')

      Bash::exec('touch new.txt')
      Git::add
      Git::commit 'add new.txt'

      Bash::exec('git tag finish')

      Bash::exec('touch anothernew.txt')
      Git::add
      Git::commit 'add anothernew.txt'

      commits = Git::commits('start', 'finish')

      expect(commits.count).to eq 1

      expect(commits[0].hash).not_to be nil
      expect(commits[0].message).to eq 'add new.txt'
      expect(commits[0].date).not_to be nil
      expect(commits[0].author).to eq 'test'
    end
  end

  describe 'commit' do
    it 'commits with the correct message' do
      Bash::exec('touch new.txt')
      Git::add
      Git::commit 'add new.txt'

      expect(Bash::exec("git log --pretty=format:'%h %ad%x20%s%x20%x28%an%x29' --date=short | head -n1")).to include "add new.txt"
    end
  end

  describe 'add' do
    it 'adds all changed files when no files passed' do
      Bash::exec('touch new.txt')

      staged_file_count = Bash::exec("git status -s | grep 'A' | wc -l").strip.to_i
      untracked_file_count = Bash::exec("git status -s | grep '??' | wc -l").strip.to_i

      expect(staged_file_count).to eq 0
      expect(untracked_file_count).to eq 1

      Git::add

      staged_file_count = Bash::exec("git status -s | grep 'A' | wc -l").strip.to_i
      untracked_file_count = Bash::exec("git status -s | grep '??' | wc -l").strip.to_i

      expect(staged_file_count).to eq 1
      expect(untracked_file_count).to eq 0
    end

    it 'adds single file' do
      Bash::exec('touch new.txt')
      Bash::exec('touch new_untracked.txt')

      expect(Bash::exec("git status -s | grep '??' | wc -l").strip.to_i).to eq 2

      Git::add 'new.txt'

      expect(Bash::exec("git status -s | grep '??' | wc -l").strip.to_i).to eq 1
      expect(Bash::exec("git status -s | grep 'A' | wc -l").strip.to_i).to eq 1
    end

    it 'adds array of files' do
      Bash::exec('touch new.txt')
      Bash::exec('touch new_untracked.txt')

      expect(Bash::exec("git status -s | grep '??' | wc -l").strip.to_i).to eq 2

      Git::add ['new.txt', 'new_untracked.txt']

      expect(Bash::exec("git status -s | grep '??' | wc -l").strip.to_i).to eq 0
      expect(Bash::exec("git status -s | grep 'A' | wc -l").strip.to_i).to eq 2
    end
  end
end
