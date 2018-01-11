require 'rake'
require_relative 'context'
require_relative '../../lib/bash'
require_relative '../spec_util'

describe Releasinator do

  include_context 'setup'

  describe 'validate:eof_newlines' do
    it 'adds newlines to the ends of files and commits files' do
      task = Rake::Task['validate:eof_newlines']

      file = File.new(File.join(@dir, 'tmp.sh'), File::CREAT|File::TRUNC|File::RDWR)
      file.write 'some data'
      file.close

      Git::add
      Git::commit 'add tmp.sh'

      task.invoke

      expect(Git::commits.last.message).to eq '[RELEASE] add EOF newlines'
    end
  end
end
