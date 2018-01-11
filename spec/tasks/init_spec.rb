require 'rake'
require_relative 'context'
require_relative '../../lib/bash'
require_relative '../../lib/default_config'
require_relative '../spec_util'

describe Releasinator do

  include_context 'setup'

  describe 'init' do
    it 'creates default releasinator file' do
      @task.invoke

      releasinator_filepath = File.join(@dir, '.releasinator.rb')

      expect(File.exist?(releasinator_filepath)).to be true

      releasinator_file = File.open(releasinator_filepath)

      expect(releasinator_file.read).to eq DEFAULT_CONFIG
    end

    it 'does not create a default releasinator file if one already exists' do
      Bash::exec('echo "hello" > .releasinator.rb')
      @task.invoke

      expect(File.open(File.join(@dir, '.releasinator.rb')).read).to eq "hello\n"
    end
  end
end
