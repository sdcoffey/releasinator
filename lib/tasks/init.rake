require_relative '../default_config'

desc "initialize releasinator and create new .releasinator.rb files"
task :init do
  if File.exist? CONFIG_FILE_NAME
    puts 'A .releasinator.rb file already exists.'
  else
    out_file = File.new("#{CONFIG_FILE_NAME}", "w")

    out_file.write(DEFAULT_CONFIG)
    out_file.close

    puts 'Created new default .releasinator.rb file. You should check this file into your VCS.'
  end
end
