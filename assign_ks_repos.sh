#!/usr/bin/env bash

## Author: Pablo Hess <phess@redhat.com>
## Goal: Re-assign kickstart repos to hosts that have lost their original
##       kickstart repos for any reason.

HOST_IDS="${1:-all}"
NOOP="false"

WARNING="
This is $(basename $0), authored for a particular Red Hat Support ticket.
This script should not be run if not recommended by a Red Hat Support representative.
Please wait while this script calls 'foreman-rake console' in the background...
"

echo "$WARNING"

cat << EORAKE | foreman-rake console >/dev/null
conf.echo = false
noop = "$NOOP" == "true"
if "$HOST_IDS" == "all"
  host_space = Host.all
else
  host_space = Host.all.select {|h| "$HOST_IDS".split(',').include? h.id.to_s}
end
    # Find hosts with a nil medium_provider
    need_ks_update = host_space.select {|onehost| onehost.medium_provider == nil}
    puts "Found #{need_ks_update.count} hosts potentially needing a kickstart update."
    host_count = need_ks_update.count
    if host_count == 0
      STDERR.puts " [QUIT] No hosts on the list need a kickstart update. Exiting now."
      exit(0)
    end

    # Find appropriate kickstart repo for host, update it if found
    need_ks_update.each_with_index do |h, i|
      STDERR.print "(#{i+1}/#{host_count}) #{h.name}: "  # No new line
      begin
        host_os = h.operatingsystem
        STDERR.print "host_os=#{host_os}"
        correct_ks_repos = host_os.distribution_repositories(h)
      rescue NoMethodError # host nas no operating system or operating system has no ks repo
        STDERR.puts "No operating system defined for host or no kickstart repo for host's operating system. Skipping."
        next
      end
      # RHEL 7 and lower: single distribution_repositories(host) result
      correct_ks_repo = correct_ks_repos.first if host_os.name == "RedHat" && host_os.major.to_i <= 7

      # RHEL 8 and later: choose the one withe variant="BaseOS"
      correct_ks_repo = correct_ks_repos.where(:distribution_variant => "BaseOS").first if host_os.name == "RedHat" && host_os.major.to_i > 7

      begin
        unless correct_ks_repo
          STDERR.puts "No kickstart repos to choose from. Skipping."
          next
        end
        unless noop
          STDERR.print " Correct kickstart repo ID is #{correct_ks_repo.id}"
          STDERR.print " Setting now..."
          User.as_anonymous_admin do
            current_organization = h.organization
            current_location = h.location
            h.content_source = h.content_source
            h.content_facet.kickstart_repository_id = correct_ks_repo.id
            saved = h.save
          end
          unless saved=nil
            STDERR.puts "   [OK]"
          else
            STDERR.puts "   [FAILED]"
          end
        end
      rescue
        STDERR.puts "    [FAILED] (moving on)"
      end
    end
EORAKE

echo "[EXIT]"
