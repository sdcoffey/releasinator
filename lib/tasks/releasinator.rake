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

import 'lib/tasks/init.rake'
import 'lib/tasks/validate.rake'

include Releasinator

DOWNSTREAM_REPOS = "downstream_repos"

desc "read and validate the config, adding one if not found"
task :config do
  @releasinator_config = ConfigHash.new(verbose == true, Rake.application.options.trace == true)
  @releasinator_config.freeze
  @validator = Validator.new(@releasinator_config)
  @validator.freeze
  @validator.validate_config
end

desc "Update release version and CHANGELOG"
task :update_version_and_changelog do
  begin
    Changelog::Updater.bump_version do |version, semver_type|
      @releasinator_config[:update_version_method].call(version, semver_type)
      Changelog::Updater.prompt_for_change_log(version, semver_type)

      GitUtil.stage
      if @releasinator_config.has_key? :update_version_commit_message
        GitUtil.commit(@releasinator_config[:update_version_commit_message])
      else
        GitUtil.commit("Update version and CHANGELOG.md for #{version}")
      end
    end
  rescue Exception => e
    GitUtil.reset_head(true)
    Printer.fail("Failed to update version: #{e}")
    abort()
  end
end

desc "release all"
task :release => [:"validate:all"] do
  last_tag_raw = GitUtil.tagged_versions(remote=true, raw_tags=true).last
  last_tag = last_tag_raw
  last_tag = last_tag[1..last_tag.size] if last_tag.start_with? "v"

  if !last_tag_raw.nil? # If last tag is nil, at this point, there must be changelog entry, but this is the first releasinator release, proceed.
    commits_since_tag = GitUtil.commits(last_tag_raw)
    last_tag = Semantic::Version.new(last_tag)
    if commits_since_tag.size > 0 # There are new commits to be released
      current_version = @current_release.version
      current_version = current_version[1..current_version.size] if current_version.start_with? "v"
      if current_version > last_tag # CHANGELOG.md version is ahead of last tag. The releaser has already updated the changelog, and we've validated it
        if !Printer.ask_binary("The version from CHANGELOG.md '#{@current_release.version}' is greater than the last tagged version '#{last_tag}'. Have you already updated your version and CHANGELOG.md?")
          Printer.fail("Update your version and CHANGELOG.md and re-run rake release.")
          abort()
        end
      elsif @releasinator_config.has_key? :update_version_method
        if Printer.ask_binary("It doesn't look like your CHANGELOG.md has been updated. HEAD is #{commits_since_tag.size} commits ahead of tag #{last_tag}. Do you want to update CHANGELOG.md and version now?")
          Rake::Task[:update_version_and_changelog].invoke
          Rake::Task[:"validate:changelog"].reenable
          Rake::Task[:"validate:changelog"].invoke
        else
          Printer.fail("Update your version and CHANGELOG.md and re-run rake release.")
          abort()
        end
      else
        Printer.fail("It doesn't look like your CHANGELOG.md has been updated. HEAD is #{commits_since_tag.size} commits ahead of last tagged version '#{last_tag}'. Please update CHANGELOG.md or implement update_version_method in .releasinator.rb to allow releasinator to perform this step on your behalf. See https://github.com/paypal/releasinator for more details.")
        abort()
      end
    elsif !Printer.ask_binary("There are no new commits since last tagged version '#{last_tag}'. Are you sure you want to release?")
      abort()
    end
  elsif !Printer.ask_binary("This release (#{@current_release.version}) is the first release. Do you want to continue?")
    abort()
  end

  [:"local:build",:"pm:all",:"downstream:all",:"local:push",:"docs:all"].each do |task|
    Rake::Task[task].invoke
  end

  Printer.success("Done releasing #{@current_release.version}")
end

namespace :import do
  desc "import a changelog from release notes contained within GitHub releases"
  task :changelog => [:config] do
    Changelog::Importer.new(@releasinator_config).import(GitUtil.repo_url)
  end
end

namespace :local do
  desc "ask user whether to proceed with release"
  task :confirm => [:config, :"validate:changelog"] do
    Printer.check_proceed("You're about to release #{@current_release.version}!", "Then no release for you!")
  end

  desc "change branch for git flow, if using git flow"
  task :prepare => [:config, :"validate:changelog"] do
    if @releasinator_config.use_git_flow()
      Bash::exec("git checkout -b release/#{@current_release.version} develop") unless GitUtil.get_current_branch() != "develop"
    end
  end

  desc "tag the local repo"
  task :tag => [:config, :"validate:changelog"] do
    GitUtil.tag(@current_release.version, @current_release.changelog)
  end

  desc "iterate over the prerelease_checklist_items, asking the user if each is done"
  task :checklist => [:config] do
    @releasinator_config[:prerelease_checklist_items].each do |prerelease_item|
      Printer.check_proceed("#{prerelease_item}", "Then no release for you!")
    end
  end

  desc "build the local repo"
  task :build => [:config, :"validate:changelog", :checklist, :confirm, :prepare, :tag] do
    puts "building #{@current_release.version}" if @releasinator_config[:verbose]
    @releasinator_config[:build_method].call
    if @releasinator_config.has_key? :post_build_methods
      @releasinator_config[:post_build_methods].each do |post_build_method|
        post_build_method.call(@current_release.version)
      end
    end
  end

  desc "run the git flow branch magic (if configured) and push local to remote"
  task :push => [:config, :"validate:changelog"] do
    if @releasinator_config.use_git_flow()
      Bash::exec("git checkout master")
      Bash::exec("git merge --no-ff release/#{@current_release.version}")
      GitUtil.delete_branch "release/#{@current_release.version}"
      # still on master, so let's push it
    end

    GitUtil.push_branch("master")

    if @releasinator_config.use_git_flow()
      # switch back to develop to merge and continue development
      GitUtil.checkout("develop")
      Bash::exec("git merge master")
      GitUtil.push_branch("develop")
    end
    GitUtil.push_tag(@current_release.version)
    if @releasinator_config[:release_to_github]
      # TODO - check that the tag exists
      Bash::exec("sleep 5")
      Publisher.new(@releasinator_config).publish(GitUtil.repo_url, @current_release)
    end

    if @releasinator_config.has_key? :post_push_methods
      @releasinator_config[:post_push_methods].each do |post_push_method|
        post_push_method.call(@current_release.version)
      end
    end
  end
end

namespace :pm do
  desc "publish and wait for package manager"
  task :all => [:publish, :wait]

  desc "call configured publish_to_package_manager_method"
  task :publish => [:config, :"validate:changelog"] do
    @releasinator_config[:publish_to_package_manager_method].call(@current_release.version)
  end

  desc "call configured wait_for_package_manager_method"
  task :wait => [:config, :"validate:changelog"] do
    @releasinator_config[:wait_for_package_manager_method].call(@current_release.version)
  end
end

def copy_the_file(root_dir, copy_file, version=nil)
  Dir.mkdir(copy_file.target_dir) unless File.exist?(copy_file.target_dir)
  # use __VERSION__ to auto-substitute the version in any input param
  source_file_name = copy_file.source_file.gsub("__VERSION__", "#{version}")
  target_dir_name = copy_file.target_dir.gsub("__VERSION__", "#{version}")
  destination_file_name = copy_file.target_name.gsub("__VERSION__", "#{version}")
  Bash::exec("cp -R #{root_dir}/#{source_file_name} #{target_dir_name}/#{destination_file_name}")
end

def get_new_branch_name(new_branch_name, version)
  new_branch_name.gsub("__VERSION__", "#{version}")
end

namespace :downstream do
  desc "build, package, and push all downstream repos"
  task :all => [:reset,:prepare,:build,:package,:push] do
    Printer.success("Done with all downstream tasks.")
  end

  desc "reset the downstream repos to their starting state"
  task :reset, [:downstream_repo_index] => [:config, :"validate:changelog"] do |t, args|
    @downstream.reset(args)
  end

  desc "prepare downstream release, copying files from base_docs_dir and any other configured files"
  task :prepare, [:downstream_repo_index] => [:config, :"validate:changelog", :reset] do |t, args|
    @downstream.prepare(args)
  end

  desc "call all build_methods for each downstream repo"
  task :build, [:downstream_repo_index] => [:config,:"validate:changelog"] do |t, args|
    @downstream.build(args)
  end

  desc "tag all non-branch downstream repos"
  task :package, [:downstream_repo_index] => [:config,:"validate:changelog"] do |t, args|
    @downstream.package(args)
  end

  desc "push tags and creates draft release, or pushes branch and creates pull request, depending on the presence of new_branch_name"
  task :push, [:downstream_repo_index] => [:config,:"validate:changelog"] do |t, args|
    @downstream.push(args)
  end
end

namespace :docs do
  desc "build, copy, and push docs to gh-pages branch"
  task :all => [:build, :package, :push]

  desc "build docs"
  task :build => [:config] do
    if @releasinator_config.has_key?(:doc_build_method)
      @releasinator_config[:doc_build_method].call
      Printer.success("doc_build_method done.")
    else
      Printer.success("No doc_build_method found.")
    end
  end

  desc "copy and commit docs to gh-pages branch"
  task :package => [:config,:"validate:changelog"] do
    if @releasinator_config.has_key?(:doc_files_to_copy)
      root_dir = Dir.pwd.strip

      Dir.chdir(@releasinator_config.doc_target_dir) do
        current_branch = GitUtil.get_current_branch()

        GitUtil.init_gh_pages()
        GitUtil.reset_repo("gh-pages")
        @releasinator_config[:doc_files_to_copy].each do |copy_file|
          copy_the_file(root_dir, copy_file)
        end

        Bash::exec("git add .")
        Bash::exec("git commit -m \"Update docs for release #{@current_release.version}\"")

        # switch back to previous branch
        Bash::exec("git checkout #{current_branch}")
      end
      Printer.success("Doc files copied.")
    else
      Printer.success("No doc_files_to_copy found.")
    end
  end

  desc "push gh-pages branch"
  task :push => [:config] do
    if @releasinator_config.has_key?(:doc_build_method)
      Dir.chdir(@releasinator_config.doc_target_dir) do
        current_branch = GitUtil.get_current_branch()
        Bash::exec("git checkout gh-pages")
        GitUtil.push_branch("gh-pages")
        # switch back to previous branch
        Bash::exec("git checkout #{current_branch}")
      end
      Printer.success("Docs pushed.")
    else
      Printer.success("No docs pushed.")
    end
  end
end

def replace_string(filepath, string_to_replace, new_string)
  text = File.read(filepath)
  new_contents = text.gsub(string_to_replace, new_string)

  File.open(filepath, "w") {|file| file.puts new_contents }
end
