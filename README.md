# Useful foreman-rake scripts

Useful foreman-rake tasks. This is a personal project where I'm studying nice and fun ways to build new or improve upon existing foreman-rake tasks.

## How to use these rake scripts

1. Download the rake scripts to `/usr/share/foreman/lib/tasks/` on your Satellite 6.7 or later.

2. Run the scripts as below.


## Rake scripts included here

### export_tasks_tolerant.rake
This is the same `foreman_tasks:export_tasks` rake script any Satellite has, except it tolerates tasks failing to be exported -- it merely skips such failed tasks. This is useful when, well, the original `foreman_tasks:export_tasks` is failing while exporting an individual task for any reason.

#### Usage
~~~
# foreman-rake foreman_tasks:export_tasks_tolerant SKIP_FAILED=true TASK_SEARCH='<something something>' TASK_DAYS=123 ...
~~~

#### More information
~~~
# foreman-rake -D export_tasks_tolerant
rake foreman_tasks:export_tasks_tolerant
    Export dynflow tasks based on filter. ENV variables:
    
      * TASK_SEARCH     : scoped search filter (example: 'label = "Actions::Foreman::Host::ImportFacts"')
      * TASK_FILE       : file to export to
      * TASK_FORMAT     : format to use for the export (either html or csv)
      * TASK_DAYS       : number of days to go back
      * SKIP_FAILED     : skip tasks that fail to export (true or false[default])
    
    If TASK_SEARCH is not defined, it defaults to all tasks in the past 7 days and
    all unsuccessful tasks in the past 60 days. The default TASK_FORMAT is html
    which requires a tar.gz file extension.
~~~
 

### sync_capsule_selective.rake
This rake script syncs a single CV or repo or LCE to a single capsule.

#### Usage
~~~
# foreman-rake katello:sync_capsule_selective CAPSULE_ID=5 LIFECYCLE_ENVIRONMENT=8 CONTENT_VIEW=13 REPOSITORY=21
# foreman-rake katello:sync_capsule_selective CAPSULE_ID=5 LIFECYCLE_ENVIRONMENT=someLCE CONTENT_VIEW="CV RHEL7 Provisioning" REPOSITORY=d35b49b0-903d-45bd-8bbe-71f434d006d6
~~~

The `LIFECYCLE_ENVIRONMENT` parameter accepts names and numeric IDs (use `hammer` to grab these IDs).
The `CONTENT_VIEW` parameter accepts CV names (i.e. spaces are allowed) or CV labels (i.e. no spaces) or numeric CV IDs (use `hammer` to grab these IDs).
The `REPOSITORY` parameter accepts numeric IDs (use `hammer`) or pulp_ids (use the web UI or postgres commands for these).

#### More information
~~~
# foreman-rake -D sync_capsule_selective
rake katello:sync_capsule_selective
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
~~~

### cv_diff.rake
Calculate content differences between two given Content View versions. The script can currently compare RPM, Repositories, or Errata.


#### Usage
~~~
# foreman-rake katello:cv_diff LEFT="RHEL 7 frontend:21.0" RIGHT=18.0 WHAT=errata
# foreman-rake katello:cv_diff LEFT="RHEL 7 frontend" 
# foreman-rake katello:cv_diff LEFT="RHEL 7 frontend" RIGHT=some_ccv:8.0 WHAT=repo
~~~

The `LEFT` and `RIGHT` parameters can be either a CV name or label or numeric ID, optionally followed by `:x.y` representing *major.minor* version.
If version numbers are omitted, latest CV version is used.
If `RIGHT` is only a version number, the same CV from LEFT will be used.
If `RIGHT` is omitted altogether, the same CV from LEFT will be used and in its latest version.

#### More information
~~~
# foreman-rake -D katello:cv_diff
rake katello:cv_diff
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
    
        * VERBOSE               : true/false Print verbose information.
        * WHAT                  : What to diff. Value is one of [ rpm, repo, errata ]
    
      Examples:
        * rake katello:cv_diff LEFT="This nice CV:15.0"
            (will diff version 15.0 and the latest version of "This nice CV")
    
        * rake katello:cv_diff LEFT="this_nice_cv" RIGHT="Other CV"
            (will diff the latest version of "this_nice_cv" to the latest version of "Other CV".)
    
        * rake katello:cv_diff LEFT=14
            (will diff the two latest versions of CV ID 14.)
    
        * rake katello:cv_diff LEFT="some cv:3.2" RIGHT="another cv:5.1"
            (will diff version 3.2 of "some cv" to version 5.1 of "another cv")
~~~

