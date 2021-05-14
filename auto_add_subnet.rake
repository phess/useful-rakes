namespace :interfaces do
  desc <<~END_DESC
    Automatically adds host NICs to matching subnets.

    Examples:
      # foreman-rake interfaces:auto_add_subnet
  END_DESC

  task :find_appropriate_subnet => :environment do
    # Loop through hosts
    Host.all.each do |h|
      myorg = h.organization
      myloc = h.location
      #puts myorg.inspect
      #puts myloc.inspect
      # Inside each host, loop through NICs
      my_nics = list_target_nics h
      puts "  Host #{h.name} (id #{h.id}) has #{my_nics.count} NICs without a subnet"
      unless my_nics.empty?
        my_nics.each do |n|
          # Inside each NIC, loop through subnets to find a matching one
          puts "  Trying to match NIC id #{n.id} to a subnet..."
          find_matching_subnet(n, myorg, myloc, Subnet.unscoped.all)
        end
      end
    end
  end

  def list_target_nics(host)
    host.interfaces.where(:type => "Nic::Managed", :subnet_id => nil)
  end

  def find_matching_subnet(nic, org, loc, subnetlist)
    # Find subnets belonging to same org and loc as the nic owner
    #puts org.inspect
    #puts loc.inspect
    #subnets = org.subnets.select { |s| s.locations.include?(loc) }
    subnets = subnetlist.select { |s| 
      s.organizations.include?(org) && s.locations.include?(loc)
    }
    puts subnets.inspect
    puts "  Found #{subnets.count} subnets belonging to org #{org.id} and loc #{loc.id}"
    # Break out of the loop as soon as a matching subnet is found and the nic is saved
    subnets.each do |s|
      puts "   Setting subnet ID #{s.id} for nic ID #{nic.id} (host ID #{nic.host.id})..."
      nic.subnet = s
      if nic.save
        puts("  ...successfully saved.")
        break
      end
      puts "   ...failed to save. Will try another one if possible."
      #break ## DEBUG
    end
  end

end
