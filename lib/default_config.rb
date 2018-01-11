RELEASINATOR_NAME = "releasinator"
CONFIG_FILE_NAME = ".#{RELEASINATOR_NAME}.rb"

DEFAULT_CONFIG = %(configatron.product_name = "test product"

# List of items to confirm from the person releasing.  Required, but empty list is ok.
configatron.prerelease_checklist_items = [
]

# The directory where all distributed docs are.  If not specified, the default is `.`.
# configatron.base_docs_dir = '.'

def build_method
  abort("please implement build_method method")
end

# The command that builds the project.  Required.
configatron.build_method = method(:build_method)

def update_version_method(version, semver_type)
  # semver_regex = /^version = "\d+.\d+.\d+"$/
  # contents = File.read("setup.py")
  # contents = contents.gsub(semver_regex, "version = \"\#{version}\"")
  # File.open("setup.py", "w") do |f|
  #   f << contents
  # end
end

# The command that populates a new version to all relevant files.  Recommended.
# configatron.update_version_method = method(:update_version_method)

def publish_to_package_manager(version)
  abort("please implement publish_to_package_manager method")
end

# The method that publishes the project to the package manager.  Required.
configatron.publish_to_package_manager_method = method(:publish_to_package_manager)


def wait_for_package_manager(version)
end

# The method that waits for the package manager to be done.  Required.
configatron.wait_for_package_manager_method = method(:wait_for_package_manager)

# True if publishing the root repo to GitHub.  Required.
configatron.release_to_github = true
)
