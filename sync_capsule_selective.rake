namespace :katello do
#  desc <<-DESC.strip_heredoc
  desc <<-DESC
    Synchronize contents from Satellite to a single Capsule. ENV variables:

      Required:
	* CAPSULE_ID            : numeric ID of the target Capsule

      Optional:
	* LIFECYCLE_ENVIRONMENT : name or numeric ID of the Lifecycle Environment to sync
	* CONTENT_VIEW          : name or label or numeric ID of the Content View to sync
	* REPOSITORY            : numeric ID or pulp id of the repository to sync
	* VERBOSE               : be verbose (true or false[default])
        * OPTIMIZED             : perform an optimized sync (true[default] or false)

      Examples:
	* rake katello:sync_capsule_selective CAPSULE_ID=1 LIFECYCLE_ENVIRONMENT=2 CONTENT_VIEW=3 REPOSITORY=5
	* rake katello:sync_capsule_selective CAPSULE_ID=8 LIFECYCLE_ENVIRONMENT=someLCE CONTENT_VIEW="My Cool CV"

      NOTE:
	Conditions will be AND'ed. This means if you select a LIFECYCLE_ENVIRONMENT that is not assigned to the
	  target Capsule then nothing will be synchronized to the target Capsule.
	If you select a CONTENT_VIEW and LIFECYCLE_ENVIRONMENT, but the former is not in the latter, then nothing
	  will be synchronized to the target Capsule.
  DESC
  task :sync_capsule_selective => ["environment", "dynflow:client"] do
    capsule_id = ENV['CAPSULE_ID']
    env = ENV['LIFECYCLE_ENVIRONMENT']
    content_view = ENV['CONTENT_VIEW']
    repository = ENV['REPOSITORY']
    optimized = ENV['OPTIMIZED']
    verbose = ENV['VERBOSE']
    User.current = User.anonymous_api_admin

    if capsule_id
      capsule = SmartProxy.find(capsule_id)
      puts "Syncing individual repos to capsule #{capsule.name}" if verbose == "true"
    else
      puts "ERROR: no CAPSULE_ID given. I need a CAPSULE_ID. Run ``rake -D katello:sync_capsule_selective'' to read about required and optional variables."
      exit 3
    end
    
    options = {}
    if env
      # Look up by name first, then by ID if name doesn't work
      lce = Katello::KTEnvironment.find_by(:name => env)
      unless lce
	lce = Katello::KTEnvironment.find(env.to_i)
      end
      puts "INFO: Selecting Lifecycle Environment #{lce.name} (ID #{lce.id}) for syncing to capsule #{capsule.name} (ID #{capsule.id})." if verbose == "true"
      options[:environment_id] = lce.id
      lcename = lce.name
    else
      lcename = "[none chosen]"
    end

    if optimized == "false"
      options[:skip_metadata_check] = true
    end

    if content_view
      # Look up by name first, then label, then ID
      cv = Katello::ContentView.find_by(:name => content_view)
      unless cv
	cv = Katello::ContentView.find_by(:label => content_view)
	unless cv
	  cv = Katello::ContentView.find(content_view.to_i)
	end
      end
      puts "INFO: Selecting Content View #{cv.name} (ID #{cv.id}) for syncing to capsule #{capsule.name} (ID #{capsule.id})." if verbose == "true"
      options[:content_view_id] = cv.id
      cvname = cv.name if verbose == "true"
    else
      cvname = "[none chosen]" if verbose == "true"
    end

    if repository
      # Look up by numeric ID (Katello) then by pulp_id (UUID)
      repo = Katello::Repository.find(repository.to_i)
      unless repo
	repo = Katello::Repository.find_by(:pulp_id => repository)
      end
      puts "INFO: Selecting Repository #{repo.name} (ID #{repo.id}) for syncing to capsule #{capsule.name} (ID #{capsule.id})." if verbose == "true"
      options[:repository_id] = repo.id
      reponame = repo.name if verbose == "true"
    else
      reponame = "[none chosen]" if verbose == "true"
    end

    if verbose == "true"
      puts "Will now sync capsule #{capsule.name} with these parameters:"
      puts "  capsule.......: #{capsule}" 
      puts "  environment...: #{lcename}"
      puts "  content_view..: #{cvname}"
      puts "  repository....: #{reponame}"
      puts " **********"
      puts " ** NOTE ** If the given environment or content_view or repository is not assigned to this capsule,"
      puts " **      ** then nothing will be synced to this capsule."
      puts " **      **"
      puts " **      ** The same applies in case e.g. the chosen Content View is not published to the chosen"
      puts " **      ** Lifecycle Environment."
      puts " **********"
    end
    #task = ForemanTasks.async_task(::Actions::Katello::CapsuleContent::Sync, capsule, options)
    ForemanTasks.sync_task(Actions::Pulp::Orchestration::Repository::RefreshRepos, capsule, options)
    ForemanTasks.sync_task(Actions::Pulp3::Orchestration::Repository::RefreshRepos, capsule, options) if capsule.pulp3_enabled?
    task = ForemanTasks.async_task(::Actions::Katello::CapsuleContent::Sync, capsule, options)
    puts "  *** Capsule sync task is started with task ID #{task.id} ***"
    puts "  *** Capsule sync task status is currently #{task.state} and result is #{task.result} ***"
  end
end
