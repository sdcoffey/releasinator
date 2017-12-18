require_relative "../lib/bash"

describe Bash do

  describe 'command' do
    it 'runs commands on the shell' do
      tmpdir = Dir.mktmpdir

      Dir.chdir(tmpdir) do
        Bash::exec('echo "hello world!" > hello.txt')

        file = File.open(File.join(tmpdir, 'hello.txt'))
        expect(file.read).to eq "hello world!\n"
      end
    end

    it 'returns shell output' do
      expect(Bash::exec('echo "hello world"')).to eq "hello world\n"
    end

    it 'executes command in desired dir' do
      tmpdir = Dir.mktmpdir

      Bash::exec('echo "hello world!" > hello.txt', false, tmpdir)

      file = File.open(File.join(tmpdir, 'hello.txt'))
      expect(file.read).to eq "hello world!\n"
    end
  end
end

