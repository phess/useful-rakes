namespace :katello do
  desc <<-DESC
    Reload errata counts for all hosts matching an optional search filter. ENV variables:

      Optional:
        * HOST_SEARCH           : search filter for hosts to reload errata counts for, e.g. HOST_SEARCH='name=myhost.example.com or host_collection ~ *_floor_servers'
	* VERBOSE               : be verbose (true or false[default])

      Examples:
	* rake katello:reload_errata_status  # Reload errata status for all hosts
        * rake katello:create_pulp_repos HOST_SEARCH='host_collection ~ *_floor_servers'  # Reload errata status for hosts in any of the *_floor_servers host collections

  DESC
  task :reload_errata_status => ["environment"] do
    host_filter = ENV['HOST_SEARCH']
    def verbose
      ["1", "true", "yes", "y"].include? ENV['VERBOSE'].downcase
    end
    User.current = User.anonymous_api_admin

    def get_host_errata_status(host)
      begin
      {
        :applicable_sec_errata_count  => host.content_facet.applicable_errata.security.size ||=0,
        :installable_sec_errata_count => host.content_facet.installable_errata.security.size ||=0,
        :errata_status => host.errata_status
      }
      rescue
      {
        :applicable_sec_errata_count  => 0,
        :installable_sec_errata_count => 0,
        :errata_status => 0
      }
      end
    end

    def diff_arrays(arr1, arr2)
      diff_result = {}
      arr1.each do |k,v|
        diff_result[k] = [v, arr2[k]] if v != arr2[k]
      end
      return diff_result
    end

    def print_diff_arrays(array_of_diffs)
      output = ""
      array_of_diffs do |k,vs|
        output << "#{k}:#{vs[0]}->#{vs[1]} "
      end
      return output
    end

    def reload_host_errata_status(host)
      # Grab before & after values to report on which hosts changed and by how much
      before = get_host_errata_status(host)
      # Update errata applicability counts and status, then reload host
      begin
        host.content_facet.update_applicability_counts
        host.content_facet.update_errata_status
        host.reload
      rescue
        puts "::WARNING:: #{host.name} (ID #{host.id}) may be missing content_facets, nothing to do. "
      end
      # Grab the "after" values to report on
      after = get_host_errata_status(host)

      changes = diff_arrays(before, after)
      if changes
        #output = "#{host.name} (#{print_diff_arrays(changes)})"
        output = "#{host.name} (#{before} -> #{after})"
      end
    end

    if host_filter
      hostlist = Host.search_for(host_filter)
    else
      hostlist = Host.all
    end

    totalcount = hostlist.count
    donecount = 0

    puts "::INFO:: Running through #{totalcount} hosts"
    hostlist.each do |host|
      puts "(#{donecount+1}/#{totalcount}) #{host.name} (ID #{host.id})"
      reload_host_errata_status host
      donecount +=1
    end
  end
end
