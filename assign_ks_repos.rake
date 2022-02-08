namespace :hosts do
  desc <<~END_DESC
    Finds hosts without an installation medium and tries to auto-assign
    the most appropriate one based on the host Operating System.

    Arguments:
       HOST_ID=<numeric ID>               Process only a single host (the one with the given numeric ID)
       COMMIT=<true/false> (default=true) If false, no change is made to hosts.

    Examples:
      # foreman-rake hosts:assign_ks_repo -- goes through all hosts, changing hosts that need changing.
      # foreman-rake hosts:assign_ks_repo COMMIT=false HOST_ID=2398 -- evaluates only host id 2398 and does not actually make any change to it.
  END_DESC

  host_id = ENV["HOST_ID"]
  noop = ENV["COMMIT"] == "false" || ENV["COMMIT"] == "False"

  task :assign_ks_repo => :environment do
    if host_id
      host_space = [Host.find(host_id.to_i)]
    else
      host_space = Host.all
    end
    # Find hosts with a nil medium_provider
    need_ks_update = host_space.select {|onehost| onehost.medium_provider == nil}
    #need_ks_update = []
    #host_space.select do |h|
    #  need_ks_update << h if h.medium_provider == nil
    #end

    puts "Found #{need_ks_update.count} hosts potentially needing a kickstart update."

    host_count = need_ks_update.count
    exit(0) if host_count == 0

    # Find appropriate kickstart repo for host, update it if found
    need_ks_update.each_with_index do |h, i|
      print "(#{i+1}/#{host_count}) #{h.name}: "  # No new line
      begin
        host_os = h.operatingsystem
        correct_ks_repos = host_os.distribution_repositories(h)
      rescue NoMethodError # host nas no operating system or operating system has no ks repo
        puts "No operating system defined for host or no kickstart repo for host's operating system. Skipping."
        next
      end
      # RHEL 7 and lower: single distribution_repositories(host) result
      correct_ks_repo = correct_ks_repos.first if host_os.name == "RedHat" && host_os.major.to_i <= 7

      # RHEL 8 and later: choose the one withe variant="BaseOS"
      correct_ks_repo = correct_ks_repos.where(:distribution_variant => "BaseOS").first if host_os.name == "RedHat" && host_os.major.to_i > 7

      begin
        if correct_ks_repo
          print "correct kickstart repository is #{correct_ks_repo.id}." if correct_ks_repo
        else
          puts "No kickstart repos to choose from. Skipping."
          next
        end
        unless noop
          print "Setting now..."
          h.content_facet.kickstart_repository_id = correct_ks_repo.id
          h.save
          print "   [OK]"
        end
      rescue
        puts "    [FAILED] (moving on)"
        puts correct_ks_repo.inspect
      end
      puts ""
    end
  end
end
