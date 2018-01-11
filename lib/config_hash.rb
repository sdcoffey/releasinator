require 'configatron'
require_relative 'bash'
require_relative 'default_config'
require_relative 'git/git'

module Releasinator
  class ConfigHash < Hash
    def initialize(verbose, trace)
      update({:releasinator_name => RELEASINATOR_NAME})
      update({:verbose => verbose})
      update({:trace => trace})

      require_file_name = "./.#{RELEASINATOR_NAME}.rb"
      begin
        require require_file_name
      rescue LoadError
      end

      configatron.lock!
      loaded_config_hash = configatron.to_h

      update(loaded_config_hash)

      puts "loaded config:" + self.to_s if verbose
    end

    def use_git_flow
      return self[:use_git_flow] if self.has_key? :use_git_flow

      false
    end

    def base_dir
      return self[:base_docs_dir] if self.has_key?(:base_docs_dir)

      '.'
    end

    def doc_target_dir
      return self[:doc_target_dir] if self.has_key?(:doc_target_dir)

      '.'
    end
  end
end
