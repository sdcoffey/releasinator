require 'rake'
require_relative '../lib/bash'

describe Releasinator do

  def create_local_repo
    dir = Dir.mktmpdir
    Dir.chdir dir

    Bash::exec("git init")
    Bash::exec("git config user.name 'test'")
    Bash::exec("git config user.email 'test@example.com'")

    dir
  end

  before do
    load File.join(File.dirname(File.dirname(__FILE__)), 'lib/tasks/releasinator.rake')
    Rake::Task.define_task(:environment)

    @wd = Dir.pwd
    @dir = create_local_repo
  end

  after do
    Rake.application.clear
    # FileUtils.remove_dir @dir
    Dir.chdir @wd
  end

  describe 'config' do
    # it 'validates changelog' do
    #   @app['validate:changelog'].invoke
    #   puts @app.inspect
    # end
  end

  describe 'validate:config' do
    it 'validates config' do

    end
  end

  describe 'validate:eof_newlines' do
    it 'adds newlines to the ends of files and commits files' do
      task = Rake::Task['validate:eof_newlines']

      file = File.new(File.join(@dir, 'tmp.sh'), File::CREAT|File::TRUNC|File::RDWR)
      file.write 'some data'
      file.close

      Git::add
      Git::commit 'add tmp.sh'

      task.invoke

      puts Bash::exec('git status -s')
      expect(Git::commits.last.message).to eq '[RELEASE] add EOF newlines'
    end
  end
end
