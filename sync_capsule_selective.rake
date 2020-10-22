namespace :katello do
  desc <<-DESC.strip_heredoc
    Synchronize contents from Satellite to a single Capsule. ENV variables:

      Required:
        * CAPSULE_ID            : numeric ID of the target Capsule

      Optional:
        * LIFECYCLE_ENVIRONMENT : name or numeric ID of the Lifecycle Environment to sync
        * CONTENT_VIEW          : name or label or numeric ID of the Content View to sync
        * REPOSITORY            : numeric ID or pulp id of the repository to sync
        * VERBOSE               : be verbose (true or false[default])

      Examples:
        * rake katello:sync_capsule_selective CAPSULE_ID=1 LIFECYCLE_ENVIRONMENT=2 CONTENT_VIEW=3 REPOSITORY=5
        * rake katello:sync_capsule_selective CAPSULE_ID=8 LIFECYCLE_ENVIRONMENT=someLCE CONTENT_VIEW="My Cool CV"

      NOTE:
        Conditions will be AND'ed. This means if you select a LIFECYCLE_ENVIRONMENT that is not assigned to the
          target Capsule then nothing will be synchronized to the target Capsule.
        If you select a CONTENT_VIEW and LIFECYCLE_ENVIRONMENT, but the former is not in the latter, then nothing
          will be synchronized to the target Capsule.
  DESC
  task :sync_capsule_selective => ["environment", "check_ping"] do
    capsule_id = ENV['CAPSULE_ID']
    env = ENV['LIFECYCLE_ENVIRONMENT']
    content_view = ENV['CONTENT_VIEW']
    repository = ENV['REPOSITORY']
    force = ENV['FORCE']
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
      options[:environment_id] = lce.id
    end

    if force
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
      options[:content_view_id] = cv.id
    end

    if repository
      # Look up by numeric ID (Katello) then by pulp_id (UUID)
      repo = Katello::Repository.find(repository.to_i)
      unless repo
        repo = Katello::Repository.find_by(:pulp_id => repository)
      end
      options[:repository_id] = repo.id
    end

    if verbose == "true"
      puts "Will now sync capsule #{capsule.name} with these parameters:"
      puts "  capsule.......: #{capsule}"
      puts "  environment...: #{lce}"
      puts "  content_view..: #{cv}"
      puts "  repository....: #{repo}"
      puts " **********"
      puts " ** NOTE ** If the given environment or content_view or repository is not assigned to this capsule,"
      puts " **      ** then nothing will be synced to this capsule."
      puts " **      **"
      puts " **      ** The same applies in case e.g. the chosen Content View is not published to the chosen"
      puts " **      ** Lifecycle Environment."
      puts " **********"
    end
    task = ForemanTasks.async_task(::Actions::Katello::CapsuleContent::Sync, capsule, options)
  end
end
