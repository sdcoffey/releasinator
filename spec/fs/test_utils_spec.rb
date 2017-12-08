require 'fileutils'
require 'tempfile'
require_relative '../../lib/fs/utils'
require_relative '../../lib/command_processor'

include Releasinator

describe FileSystem::Utils do

  describe 'add_newlines' do
    before :each do
      @tmpdir = Dir::mktmpdir
      Dir.chdir(@tmpdir) do
        CommandProcessor.command("git init")
        CommandProcessor.command("git config user.name 'test'")
        CommandProcessor.command("git config user.email 'test@example.com'")
      end
    end

    after :each do
      #FileUtils.remove_dir(@tmpdir)
    end

    it 'adds newlines when there arent any' do
      Dir.chdir(@tmpdir) do
        file = File.new(File.join(@tmpdir, 'tmp.sh'), File::CREAT|File::TRUNC|File::RDWR)
        file.write('some data')
        file.close

        CommandProcessor.command('git add -A')
        CommandProcessor.command('git commit -m"add some data"')

        FileSystem::Utils.add_newlines

        file = File.open(File.join(@tmpdir, 'tmp.sh'))

        expect(file.read).to eq "some data\n"
      end
    end

    it 'does not add newlines to non-important files' do
      Dir.chdir(@tmpdir) do
        file = File.new(File.join(@tmpdir, 'tmp.tmp'), File::CREAT|File::TRUNC|File::RDWR)

        file.write('some data')
        file.close

        CommandProcessor.command('git add -A')
        CommandProcessor.command('git commit -m"add some data"')

        FileSystem::Utils.add_newlines

        changed_count = CommandProcessor.command("git status -s | wc -l").strip.to_i

        expect(changed_count).to eq 0
      end
    end

    it 'does not add extra newlines to files with newlines already added' do
      Dir.chdir(@tmpdir) do
        file = File.new(File.join(@tmpdir, 'tmp.sh'), File::CREAT|File::TRUNC|File::RDWR)

        file.write("some data\n")
        file.close

        CommandProcessor.command('git add -A')
        CommandProcessor.command('git commit -m"add some data"')

        FileSystem::Utils.add_newlines

        changed_count = CommandProcessor.command("git status -s | wc -l").strip.to_i

        expect(changed_count).to eq 0
      end
    end
  end
end
