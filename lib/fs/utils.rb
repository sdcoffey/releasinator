require_relative '../git_util'

module FileSystem
  class Utils

    TEXT_FILE_EXTENSIONS = [
      ".md",
      ".txt",
      ".ini",
      ".in",
      ".xml",
      ".gitignore",
      ".npmignore",
      ".html",
      ".css",
      ".h",
      ".cs",
      ".go",
      "Gemfile",
      "Gemfile.lock",
      ".rspec",
      ".gemspec",
      ".podspec",
      ".rb",
      ".java",
      ".php",
      ".py",
      ".js",
      ".yaml",
      ".json",
      ".sh",
      ".groovy",
      ".gemspec",
      ".gradle",
      ".settings",
      ".properties",
      "LICENSE",
      "Rakefile",
      "Dockerfile"
    ]

    def self.add_newlines(working_directory=Dir.pwd)
      all_git_files = GitUtil.all_files.split

      important_git_text_files = all_git_files.select{ |filename|
        TEXT_FILE_EXTENSIONS.any? { |extension|
          filename.end_with?(extension)
        }
      }

      important_git_text_files.each do |filename|
        Bash::exec("tail -c1 #{filename} | read -r _ || echo >> #{filename}")
      end

      important_git_text_files
    end
  end
end
