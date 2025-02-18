require 'byebug'
require 'yaml'
require 'ostruct'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/module/attribute_accessors'
require 'logger'

# rubocop:disable Style/ClassVars
# this is a mostly(?) read-only module to supply the simple config to everywhere that needs it and some common methods
module Config

  cattr_reader :logger, :environment, :update_base_url, :oai_base_url, :sets
  def self.initializer(environment: 'development', logger_std_out: false)
    proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    path = File.join(proj_root, 'config', 'notifier.yml')
    @@settings = ActiveSupport::HashWithIndifferentAccess.new(YAML.load_file(path)[environment])
    @@environment = environment

    @@logger = if logger_std_out
                 Logger.new($stdout)
               else
                 # this isn't used by rake task and always set to standard out
                 Logger.new(File.join(proj_root, 'log', "#{environment}.log"))
               end
    # this is an example from the docs for escaping sensitive info, but it's simply changing the time to be UTC
    @@original_formatter = Logger::Formatter.new
    @@logger.formatter = proc { |severity, datetime, progname, msg|
      @@original_formatter.call(severity, datetime.utc, progname, msg.dump)
    }

    @@update_base_url = @@settings[:update_base_url]
    @@oai_base_url = @@settings[:oai_base_url]
    @@sets = @@settings[:sets]
  end
end
# rubocop:enable Style/ClassVars
