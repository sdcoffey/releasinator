require_relative '../lib/bash'

module SpecUtil
  def self.create_local_repo
    dir = Dir.mktmpdir
    Dir.chdir dir

    Bash::exec("git init")
    Bash::exec("git config user.name 'test'")
    Bash::exec("git config user.email 'test@example.com'")

    dir
  end
end
