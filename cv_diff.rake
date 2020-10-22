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
  task :cv_diff => ["environment", "check_ping"] do
    cv_id = ENV['CONTENT_VIEW']
    versions = ENV['VERSIONS']
    verbose = ENV['VERBOSE']
    User.current = User.anonymous_api_admin

    cv = Katello::ContentView.find(cv_id)
    cv_versions = versions.split(',', 2)
    cv1 = cv.versions.find(cv_versions.first.to_i)
    cv2 = cv.versions.find(cv_versions.last.to_i)
    $allcvs = [ cv1, cv2 ]

    def cvmajmin(cvversion)
      return "#{cvversion.major}.#{cvversion.minor}"
    end

    def cvname(cvversion)
      return cvversion.content_view.name
    end

    def cvvname(cvversion)
      return cvname(cvversion) + ":" + cvmajmin(cvversion)
    end

    def cvpkgs(cvversion)
      return cvversion.packages
    end

    def othercv(cvversion)
      # Find who the "other" CV is
      othercv = ($allcvs - [ cvversion ]).first
      return othercv
    end

    def cvexclusivepkgs(cvversion)
      theother = othercv(cvversion)
      return cvversion.packages - theother.packages
    end

    puts "Diffing Content View '#{cv.name}' versions #{cvmajmin(cv1)} and #{cvmajmin(cv2)}"
    puts "Package counts are #{cvpkgs(cv1).count} and #{cvpkgs(cv2).count}."

    puts ""
    [ cv1, cv2 ].each do
      |onecv|
      puts "#{cvvname(onecv)} has #{cvexclusivepkgs(onecv).count} exclusive packages that the other Content View Version does not."
    end

    puts ""
    [ cv1, cv2 ].each do
      |onecv|
      puts "List of packages exclusive to #{cvvname(onecv)}:"
      cvexclusivepkgs(onecv).each_with_index do |pkg, idx|
        puts "#{idx+1}:\t#{pkg.nvra}"
      end
      puts "------"
    end
  end   
end
