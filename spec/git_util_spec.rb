require 'fileutils'
require_relative '../lib/git_util'
require_relative '../lib/command_processor'
include Releasinator

describe GitUtil do

  describe 'add' do

    before(:each) do
      @wd = Dir.pwd

      @dir = Dir.mktmpdir
      Dir.chdir @dir

      CommandProcessor.command("git init")
      CommandProcessor.command("git config user.name 'test'")
      CommandProcessor.command("git config user.email 'test@example.com'")
    end

    after(:each) do
      FileUtils.remove_dir(@dir)
      Dir.chdir @wd
    end

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
end
