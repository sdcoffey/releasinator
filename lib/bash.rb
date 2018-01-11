require 'colorize'
require_relative 'printer'

module Bash
  def self.exec(command, live_output=false, working_directory=Dir.pwd)
    output = nil

    Dir.chdir(working_directory) do
      self.print Time.now.utc.iso8601 + ": " + "#{Dir.pwd}".bold + " exec:" + " #{command}".bold

      if live_output
        self.print "...with live output (forked process)".bold

        return_code = nil
        r, io = IO.pipe
        pid = fork do
          return_code = system(command, :out => io, :err => io)
          if !return_code
            Printer.fail("Execution failure.")
            abort()
          end
        end
        io.close
        output = ""
        r.each_line do |line|
          self.print line.strip.white
          output << line
        end

        Process.wait(pid)
        fork_exitstatus = $?.exitstatus
        if 0 != fork_exitstatus
          Printer.fail("Forked process failed with exitstatus:#{fork_exitstatus}")
          abort()
        end
      else
        output = `#{command}`
        exitstatus = $?.exitstatus
        if 0 != exitstatus
          Printer.fail("Process failed with exitstatus:#{exitstatus}")
          abort()
        end
      end
    end

    output
  end

  # waits for the input command to return non-empty output.
  def self.wait_for(command_to_execute, wait_for_seconds=30)
    while "" == self.exec(command_to_execute)
      self.print "Returned empty output.  Sleeping #{wait_for_seconds} seconds."
      wait_for_seconds.times do
        print "."
        sleep 1
      end
      self.print ''
    end

    Printer.success("Returned non-empty output.")
  end

  def self.print(msg)
    puts msg if ARGV.include?('--verbose') || ARGV.include?('-v') || ENV['VERBOSE']
  end
end
