require 'rubygems'
require 'bundler/setup'
require 'colorize'
require 'json'
require 'tempfile'
require_relative '../bash'
require_relative '../config_hash'
require_relative '../copy_file'
require_relative '../current_release'
require_relative '../downstream'
require_relative '../downstream_repo'
require_relative '../publisher'
require_relative '../validator'
require_relative '../changelog/importer'
require_relative '../changelog/updater'
require_relative '../fs/utils'

namespace :validate do
  desc "validate important text files end in a newline character"
  task :eof_newlines do
    changed_files = FileSystem::Utils.add_newlines

    if changed_files.count > 0
      Git::add changed_files
      Git::commit '[RELEASE] add EOF newlines'
    end
  end

  desc "validate the presence, formatting, and semver sequence of CHANGELOG.md"
  task :changelog => [:config, :git] do
    @current_release = @validator.validate_changelog(DOWNSTREAM_REPOS)
    @current_release.freeze
    @downstream = Downstream.new(@releasinator_config, @validator, @current_release)
    @downstream.freeze
  end

  desc "validate releasinator is up to date"
  task :releasinator_version => :config do
    @validator.validate_releasinator_version
  end

  desc "validate your path has some useful tools"
  task :paths => :config do
    @validator.validate_in_path("wget")
    @validator.validate_in_path("git")
  end

  desc "validate git version is acceptable"
  task :git_version => :config do
    @validator.validate_git_version
  end

  desc "validate git reports no untracked, unstaged, or uncommitted changes"
  task :git => :config do
    @validator.validate_clean_git
  end

  desc "validate current branch matches the latest on the server and follows naming conventions"
  task :branch => [:config, :changelog] do
    @validator.validate_branches(@current_release.version)
  end

  desc "validate the presence of README.md, renaming a similar file if found"
  task :readme => :config do
    @validator.validate_exist('.', "README.md", DOWNSTREAM_REPOS)
    @validator.validate_exist(@releasinator_config.base_dir, "README.md", DOWNSTREAM_REPOS) if '.' != @releasinator_config.base_dir
  end

  desc "validate the presence of LICENSE, renaming a similar file if found - also validates that its referenced from README.md"
  task :license => :config do
    @validator.validate_exist(@releasinator_config.base_dir, "LICENSE", DOWNSTREAM_REPOS)
    @validator.validate_referenced_in_readme("LICENSE")
  end

  desc "validate the presence of CONTRIBUTING.md, renaming a similar file if found - also validates that its referenced from README.md"
  task :contributing => :config do
    @validator.validate_exist(@releasinator_config.base_dir, "CONTRIBUTING.md", DOWNSTREAM_REPOS)
    @validator.validate_referenced_in_readme("CONTRIBUTING.md")
  end

  desc "validate the presence of .github/ISSUE_TEMPLATE.md"
  task :issue_template => :config do
    @validator.validate_exist(@releasinator_config.base_dir, ".github/ISSUE_TEMPLATE.md", DOWNSTREAM_REPOS)
  end

  desc "validate the presence of .gitignore, adding any appropriate releasinator lines if necessary"
  task :gitignore => :config do
    @validator.validate_exist('.', ".gitignore", DOWNSTREAM_REPOS)
    @validator.validate_exist(@releasinator_config.base_dir, ".gitignore", DOWNSTREAM_REPOS) if '.' != @releasinator_config.base_dir
    @validator.validate_gitignore_contents(".DS_Store")
    if @releasinator_config.has_key?(:downstream_repos)
      @validator.validate_gitignore_contents("#{DOWNSTREAM_REPOS}/")
    end
  end

  desc "validate all submodules are on the latest origin/master versions"
  task :submodules => :config do
    @validator.validate_submodules
  end

  desc "validate the current user can push to local repo"
  task :github_permissions_local => [:config] do
    @validator.validate_github_permissions(GitUtil.repo_url)
  end

  desc "validate the current user can push to downstream repos"
  task :github_permissions_downstream, [:downstream_repo_index] => [:config] do |t, args|
    @downstream.validate_github_permissions(args)
  end

  desc "run any configatron.custom_validation_methods"
  task :custom => [:config, :changelog] do
    if @releasinator_config.has_key?(:custom_validation_methods)
      @releasinator_config[:custom_validation_methods].each do |validate_method|
        validate_method.call
      end
      Printer.success("All configatron.custom_validation_methods succeeded.")
    else
      Printer.success("No configatron.custom_validation_methods found.")
    end
  end

  desc "validate all"
  task :all =>
    [
      :paths,
      :eof_newlines,
      :git_version,
      :gitignore,
      :submodules,
      :readme,
      :changelog,
      :license,
      :contributing,
      :issue_template,
      :github_permissions_local,
      :github_permissions_downstream,
      :releasinator_version,
      :custom,
      :git,
      :branch
    ] do
    Printer.success("All validations passed.")
  end
end
