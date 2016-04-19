require 'config/factory'
require_relative 'harvester/source_config'
require_relative 'indexer/index_config'
require_relative 'indexer/metadata_mapper'

# TODO: move this out of Stash::Harvester
module Stash
  class Config

    # The persistence configuration
    # @return [PersistenceConfig] the configuration
    attr_reader :persistence_config

    # The harvest source configuration
    # @return [SourceConfig] the configuration (as an appropriate
    #   subclass of `SourceConfig` for the specified protocol)
    attr_reader :source_config

    # The index configuration
    # @return [IndexConfig] the configuration (as an apporpriate
    #   subclass of `IndexConfig` for the specified adapter)
    attr_reader :index_config

    # The metadata mapper
    # @return [MetadataMapper] the mapper (as an appropriate
    #   subclass of `MetadataMapper` for the specified mapping)
    attr_reader :metadata_mapper

    def initialize(persistence_config:, source_config:, index_config:, metadata_mapper:)
      @persistence_config = persistence_config
      @source_config = source_config
      @index_config = index_config
      @metadata_mapper = metadata_mapper
    end

    # Reads the specified file and creates a new `Config` from it.
    #
    # @param path [String] the path to read the YAML from
    # @raise [IOError] in the event the file does not exist, cannot be read, or is invalid
    def self.from_file(path)
      validate_path(path)
      begin
        env = load_env(path)
        from_env(env)
      rescue IOError
        raise
      rescue => e
        raise IOError, "Error parsing specified config file #{path}: #{e.message}"
      end
    end

    # Creates a new `Config` for the specified environment.
    #
    # @param env [Config::Factory::Environment] the configuration environment.
    def self.from_env(env)
      persistence_config = PersistenceConfig.for_environment(env, :db)
      source_config = Harvester::SourceConfig.for_environment(env, :source)
      index_config = Indexer::IndexConfig.for_environment(env, :index)
      metadata_mapper = Indexer::MetadataMapper.for_environment(env, :mapper)
      Config.new(persistence_config: persistence_config, source_config: source_config, index_config: index_config, metadata_mapper: metadata_mapper)
    end

    # Private methods

    # TODO: clean up this code and/or make Environments smarter
    def self.load_env(path)
      env_name = ENV['STASH_ENV'] || ::Config::Factory::Environments::DEFAULT_ENVIRONMENT
      env_name = env_name.to_s.downcase.to_sym
      envs = ::Config::Factory::Environments.load_file(path)

      # Fall back to parsing as single-environment config file if we have to
      envs[env_name] || ::Config::Factory::Environment.load_file(path)
    end

    private_class_method :load_env

    def self.validate_path(path)
      raise IOError, "Specified config file #{path} does not exist" unless File.exist?(path)
      raise IOError, "Specified config file #{path} is not a file" unless File.file?(path)
      raise IOError, "Specified config file #{path} is not readable" unless File.readable?(path)
    end

    private_class_method :validate_path
  end
end
