namespace :katello do
  desc <<-DESC.strip_heredoc
    Calculates and shows the difference (in terms of package contents) between two versions of the same Content View.

      Required parameters:
        * CONTENT_VIEW          : name or label or numeric ID of the Content View to examine

      Optional:
        * VERSION1              : CV version number (e.g. 14.0) or numeric ID (e.g. 523) of the first CV version to compare
        * VERSION2              : CV version number (e.g. 14.0) or numeric ID (e.g. 523) of the second CV version to compare

      Examples:
        * rake katello:cv_diff CONTENT_VIEW=my_super_cv VERSION1=13.0 VERSION2=14.1
        * rake katello:cv_diff CONTENT_VIEW=some_cv

      NOTE:
        If no CV versions are given, the 2 latest versions of CONTENT_VIEW will be compared.
        If only VERSION1 is given, the latest version of CONTENT_VIEW will be compared against VERSION1.

  DESC
  ## phess on 2020-10-19: everything below this is just a copy of sync_capules_selective.rake and needs to be actually written.
  #
  #### This works:
  #
  # cvv1 = Katello::ContentView.find( ID_OF_CVV_1 )  <=== grab this ID with hammer
  # cvv2 = Katello::ContentView.find( ID_OF_CVV_2 )  <=== grab this ID with hammer
  #
  # pkgs1 = cvv1.packages.pluck(:filename)
  # pkgs2 = cvv2.packages.pluck(:filename)
  #
  # Filenames in pkgs2 that are not in pkgs1:
  # pkgs2.each {|pkg| puts pkg unless pkgs1.includes?(pkg) }
  #
  #  BOOM. :-)
  #
  #
  #
  #
  #
  task :cv_diff => ["environment", "check_ping"] do
    capsule_id = ENV['CAPSULE_ID']
    env = ENV['LIFECYCLE_ENVIRONMENT']
    content_view = ENV['CONTENT_VIEW']
    repository = ENV['REPOSITORY']
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
