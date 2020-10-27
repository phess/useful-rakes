namespace :katello do
  desc <<-DESC.strip_heredoc
    Calculates and shows the difference (in terms of package contents) between two versions of the same Content View.

      Parameters:

          * LEFT=CV:version  : Content View and version identifiers.
                             : CV can be either a name or label or numerical ID of a Content View.
                             : Omitting the version is the same as specifying the latest version of this Content View.
                             : Version is specified as major.minor. See examples below.
                             : Examples:
                             :   LEFT="This nice CV"  -- latest version of a Content View named "This nice CV"
                             :   LEFT="this_nice_cv"  -- latest version of a Content View named or labeled "this_nice_cv"
                             :   LEFT="This nice CV:15.0"  -- version 15.0 of "This nice CV"
                             :   LEFT="this_nice_cv:15.0"  -- version 15.0 of "this_nice_cv"
                             :   LEFT="45"       -- latest version of Content View ID 45
                             :   LEFT="45:15.0"  -- version 15.0 of Content View ID 45

          * RIGHT=CV:version  : Content View and version identifiers.
                              : Same conditions as LEFT, with a single exception:
                              :   RIGHT=version (i.e. omitting the CV) will consider it to be the same Content View as LEFT.
                              :   Omitting the RIGHT argument altogether will consider this to be the second-latest version of LEFT.
                              : Examples:
                              :   RIGHT="Other nice CV"  -- will compare LEFT to the latest version of "Other nice CV"
                              :   RIGHT="other_nice_cv"  -- will compare LEFT to the latest version of "other_nice_cv"
                              :   RIGHT="Other nice CV:31.0"  -- will compare LEFT to version 31.0 of "Other nice CV"
                              :   RIGHT="other_nice_cv:31.0"  -- will compare LEFT to version 31.0 of "other_nice_cv"
                              :   RIGHT="67"  -- will compare LEFT to the latest version of Content View ID 67
                              :   RIGHT="45:31.0"  -- will compare LEFT to version 31.0 of Content View ID 67
                              :   <RIGHT is omitted>  -- will compare LEFT to the second-latest version of LEFT


        Global paramenter:

        * VERBOSE               : Print verbose information.

      Examples:
        * rake katello:cv_diff LEFT="This nice CV:15.0"
            (will diff version 15.0 and the latest version of "This nice CV")

        * rake katello:cv_diff LEFT="this_nice_cv" RIGHT="Other CV"
            (will diff the latest version of "this_nice_cv" to the latest version of "Other CV".)

        * rake katello:cv_diff LEFT=14
            (will diff the two latest versions of CV ID 14.)

        * rake katello:cv_diff LEFT="some cv:3.2" RIGHT="another cv:5.1"
            (will diff version 3.2 of "some cv" to version 5.1 of "another cv")

  DESC
  task :cv_diff => ["environment", "check_ping"] do
    left_cv_spec = ENV['LEFT']
    right_cv_spec = ENV['RIGHT']
    verbose = ENV['VERBOSE']
    User.current = User.anonymous_api_admin

    is_verbose = verbose == "true"

    left_name_and_version = left_cv_spec.split(':')
    if left_name_and_version.count == 2
      # we have name:version
      left_name, left_version = left_name_and_version
    elsif left_name_and_version.count > 2
      # cv name contains colon. Leave only the last element out as version
      left_version = left_name_and_version.pop
      left_name = left_name_and_version.join(':')
    elsif left_name_and_version.count == 1
      # cv has a name only
      left_name = left_name_and_version.first
      left_version = ""  # leave this blank as we'll use it when no RIGHT is specified. ;-)
    end

    if right_cv_spec
      right_name_and_version = right_cv_spec.split(':')
      if right_name_and_version.count == 2
        # we have name:version
        right_name, right_version = right_name_and_version
      elsif right_name_and_version.count > 2
        # cv name contains colon. Leave only the last element out as version
        right_version = right_name_and_version.pop
        right_name = right_name_and_version.join(':')
      elsif right_name_and_version.count == 1
        # cv has a name only OR a version only
        # checking if it's a version like 4.0 (very common) or 567.9876 (unlikely but possible)
        if right_name_and_version.first.match(/[1-9]\d*\.\d+/)
          right_name = left_name
          right_version= right_name_and_version.first
        else
          right_name = right_name_and_version.first
          right_version = ""
        end
      end
    else
      # RIGHT was omitted so consider it to be the same CV as LEFT and the version is empty
      right_name = ""
      right_version = ""
    end
    
    # Looking up LEFT
    # Find the CV
    results = [ "id", "name", "label" ].map {|key| Katello::ContentView.find_by(key => left_name)}.find(&:itself)
    begin
      left_cv = results
    rescue StandardError
      puts "** ERROR ** No Content View found matching #{cv_left_spec} in either ID, name, or label fields. Aborting."
      exit 1
    end
    
    # Find the CVV
    if left_version.empty?
      left_cvv = left_cv.versions.last
    else
      left_version_major, left_version_minor = left_version.split('.')
      left_cvv = left_cv.versions.find_by(:major => left_version_major, :minor => left_version_minor)
    end

    # Look up RIGHT
    if right_name.empty?
      right_cv = left_cv
      if right_version.empty?
        # Assume latest version unless left_cvv is the latest version.
        if left_cvv == right_cv.versions.last
          right_cvv = right_cv.versions[-2]
        else
          right_cvv = right_cv.versions.last
        end
      else
        # Find major and minor from LEFT CV
        right_version_major, right_version_minor = right_version.split('.')
        right_cvv = left_cv.versions.find_by(:major => right_version_major, :minor => right_version_minor)
      end
    else
      results = [ "id", "name", "label" ].map {|key| Katello::ContentView.find_by(key => right_name)}.find(&:itself)
      right_cv = results
      if right_version.empty?
        right_cvv = right_cv.versions.last
      else
        # Find major and minor for RIGHT CVV
        right_version_major, right_version_minor = right_version.split('.')
        right_cvv = right_cv.versions.find_by(:major => right_version_major, :minor => right_version_minor)
      end
    end

    cv1 = {
      "obj" => left_cvv,
      "parentname" => left_cvv.content_view.name,
      "version" => "#{left_cvv.major}.#{left_cvv.minor}",
      "displayname" => left_cvv.content_view.name + ":" + "#{left_cvv.major}.#{left_cvv.minor}",
      "cvpkgs" => left_cvv.packages.sort
    }
    cv2 = {
      "obj" => right_cvv,
      "parentname" => right_cvv.content_view.name,
      "version" => "#{right_cvv.major}.#{right_cvv.minor}",
      "displayname" => right_cvv.content_view.name + ":" + "#{right_cvv.major}.#{right_cvv.minor}",
      "cvpkgs" => right_cvv.packages.sort,
      "othercv" => cv1
    }
    cv1["othercv"] = cv2
    
    $allcvs = [ cv1, cv2 ]

    def cvexclusivepkgs(cvversion)
      return cvversion["exclusivepkgs"] if cvversion["exclusivepkgs"]
      theother = cvversion["othercv"]
      cvversion["exclusivepkgs"] = cvversion["cvpkgs"] - theother["cvpkgs"]
      return cvversion["exclusivepkgs"]
    end

    puts "Diffing Content Views\n\t'#{cv1["parentname"]}' version #{cv1["version"]} (#{cv1["cvpkgs"].count} pkgs)\n\tto\n\t'#{cv2["parentname"]}' version #{cv2["version"]} (#{cv2["cvpkgs"].count} pkgs)"

    puts ""
    $allcvs.each do
      |onecv|
      puts "#{onecv["displayname"]} has #{cvexclusivepkgs(onecv).count} exclusive packages that the #{onecv["othercv"]["displayname"]} does not."
    end

    puts ""
    $allcvs.each do
      |onecv|
      puts "List of packages exclusive to #{onecv["displayname"]}:"
      cvexclusivepkgs(onecv).pluck(:nvra).sort.each_with_index do
        |nvra, idx|
        puts "#{idx+1}:\t#{nvra}"
      end
      puts "------"
    end
  end   
end
