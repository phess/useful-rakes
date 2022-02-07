namespace :hosts do
  desc <<~END_DESC
    Finds hosts without an installation medium and tries to auto-assign
    the most appropriate one based on Operating System.

    Examples:
      # foreman-rake interfaces:clean
  END_DESC

  host_id = ENV["HOST_ID"]
  noop = ENV["NOOP"] == "true"

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

    exit(0) if need_ks_update.count == 0

    # Find appropriate kickstart repo for host, update it if found
    need_ks_update.each do |h|
      begin
        correct_ks_repo = h.operatingsystem.distribution_repositories(h).where(:distribution_variant => "BaseOS").first
        puts "#{h.name} : setting kickstart repository as #{correct_ks_repo.id}"
        unless noop
          h.content_facet.kickstart_repository_id = correct_ks_repo.id
          h.save
          puts "    *** SUCCESS saving #{h.name} ***"
        end
      rescue NoMethodError
        puts "#{h.name} : 0 kickstart repositories available. Nothing to do."
      end
    end
  end
end
