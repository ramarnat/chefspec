require 'chef'
require 'chef/client'
require 'chef/cookbook_loader'
require 'chefspec/matchers/shared'

# ChefSpec allows you to write rspec examples for Chef recipes to gain faster feedback without the need to converge a
# node.
module ChefSpec

  # The main entry point for running recipes within RSpec.
  class ChefRunner

    @step_into = []
    @resources = []

    attr_reader :resources
    attr_reader :node

    # Instantiate a new runner to run examples with.
    #
    # @param [string] cookbook_path The path to the chef cookbook(s) to be tested
    def initialize(cookbook_path=default_cookbook_path)
      the_runner = self

      Chef::Resource.class_eval do
        alias :old_run_action :run_action

        @@runner = the_runner

        def run_action(action)
          @@runner.resources << self
        end
      end

      Chef::Config[:solo] = true
      Chef::Config[:cookbook_path] = cookbook_path
      Chef::Log.verbose = true
      Chef::Log.level(:debug)
      @client = Chef::Client.new
      @client.run_ohai
      @node = @client.build_node
    end

    # Infer the default cookbook path from the location of the calling spec.
    #
    # @return [String] The path to the cookbooks directory
    def default_cookbook_path
      File.join(caller(2).first.split(':').slice(0..-3).to_s, "..", "..", "..")
    end

    # Run the specified recipes, but without actually converging the node.
    #
    # @param [array] recipe_names The names of the recipes to execute
    def converge(*recipe_names)
      recipe_names.each do |recipe_name|
        @client.node.run_list << recipe_name
      end

      @resources = []
      run_context = Chef::RunContext.new(@client.node, Chef::CookbookCollection.new(Chef::CookbookLoader.new))

      runner = Chef::Runner.new(run_context)
      runner.converge
    end

    # Find any directory declared with the given path
    #
    # @param [String] path The directory path
    # @return [Chef::Resource::Directory] The matching directory, or Nil
    def directory(path)
      find_resource('directory', path)
    end

    # Find any file declared with the given path
    #
    # @param [String] path The file path
    # @return [Chef::Resource::Directory] The matching file, or Nil
    def file(path)
      find_resource('file', path)
    end

    private

    # Find the resource with the declared type and name
    #
    # @param [String] type The type of resource - e.g. 'file' or 'directory'
    # @param [String] name The resource name
    # @return [Chef::Resource] The matching resource, or Nil
    def find_resource(type, name)
      resources.find{|resource| resource_type(resource) == type and resource.name == name}
    end

  end

end