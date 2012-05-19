module Travis
  module Api
    module Json
      module Http
        autoload :Branches,       'travis/api/json/http/branches'
        autoload :Build,          'travis/api/json/http/build'
        autoload :Builds,         'travis/api/json/http/builds'
        autoload :Job,            'travis/api/json/http/job'
        autoload :Organizations,  'travis/api/json/http/organizations'
        autoload :Repositories,   'travis/api/json/http/repositories'
        autoload :Repository,     'travis/api/json/http/repository'
        autoload :Workers,        'travis/api/json/http/workers'
      end
    end
  end
end
