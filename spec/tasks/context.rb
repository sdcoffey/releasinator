shared_context 'setup' do

  before do
    tasks_path = File.join(File.dirname(File.dirname(File.dirname(__FILE__))), 'lib/tasks', '*')
    Dir[tasks_path].each do |task|
      load task
    end

    Rake::Task.define_task(:environment)

    @task = Rake::Task[self.class.description]
    @task.reenable
    @wd = Dir.pwd
    @dir = SpecUtil::create_local_repo
  end

  after do
    Rake.application.clear
    FileUtils.remove_dir @dir
    Dir.chdir @wd
  end
end
