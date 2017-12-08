require_relative "../lib/command_processor"

describe Releasinator::CommandProcessor do

  describe 'command' do
    it 'runs commands on the shell' do
      tmpdir = Dir.mktmpdir

      Dir.chdir(tmpdir) do
        CommandProcessor.command('echo "hello world!" > hello.txt')

        file = File.open(File.join(tmpdir, 'hello.txt'))
        expect(file.read).to eq "hello world!\n"
      end
    end

    it 'returns shell output' do
      expect(CommandProcessor.command('echo "hello world"')).to eq "hello world\n"
    end

    it 'executes command in desired dir' do
      tmpdir = Dir.mktmpdir

      CommandProcessor.command('echo "hello world!" > hello.txt', false, tmpdir)

      file = File.open(File.join(tmpdir, 'hello.txt'))
      expect(file.read).to eq "hello world!\n"
    end
  end
end

