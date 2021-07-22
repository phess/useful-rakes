# rake fun

Fun with rake tasks. This is a personal project where I'm studying nice and fun ways to build new or improve upon existing foreman-rake tasks.

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
        * OPTIMIZED             : perform an optimized sync (true[default] or false)
    
          Examples:
        * rake katello:sync_capsule_selective CAPSULE_ID=1 LIFECYCLE_ENVIRONMENT=2 CONTENT_VIEW=3 REPOSITORY=5
        * rake katello:sync_capsule_selective CAPSULE_ID=8 LIFECYCLE_ENVIRONMENT=someLCE CONTENT_VIEW="My Cool CV"
    
          NOTE:
        Conditions will be AND'ed. This means if you select a LIFECYCLE_ENVIRONMENT that is not assigned to the
          target Capsule then nothing will be synchronized to the target Capsule.
        If you select a CONTENT_VIEW and LIFECYCLE_ENVIRONMENT, but the former is not in the latter, then nothing
          will be synchronized to the target Capsule.

~~~
