require 'yaml'
require 'json'
require 'sinatra/base'
require 'git'
require 'rails_best_practices'
require 'logger'
require 'net/http'
require 'net/https'

RAILSBP_CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'railsbp.yml'))[ENV['RACK_ENV']]

class Sinatra::Proxy < Sinatra::Base
  configure do
    LOGGER = Logger.new("log/sinatra.log")
    enable :logging, :dump_errors
    set :raise_errors, true
  end

  post "/hook" do
    LOGGER.info params.inspect
    begin
      @payload = JSON.parse(params[:payload])

      return "not authenticate" unless RAILSBP_CONFIG["token"] == params[:token]
      LOGGER.info "authenticated"

      return "skip" unless @payload["ref"] =~ %r|#{RAILSBP_CONFIG["branch"]}$|
      LOGGER.info "match branch"

      FileUtils.mkdir_p(build_path) unless File.exist?(build_path)
      FileUtils.cd(build_path)
      g = Git.clone(repository_url, build_name)
      Dir.chdir(analyze_path) { g.reset_hard(last_commit_id) }
      LOGGER.info "cloned"
      FileUtils.cp(config_file_path, "#{analyze_path}/config/rails_best_practices.yml")

      rails_best_practices = RailsBestPractices::Analyzer.new(analyze_path,
                                                              "format"         => "html",
                                                              "silent"         => true,
                                                              "output-file"    => output_file,
                                                              "with-github"    => true,
                                                              "github-name"    => RAILSBP_CONFIG["github_name"],
                                                              "last-commit-id" => last_commit_id,
                                                              "with-git"       => true,
                                                              "template"       => template_file
                                                             )
      rails_best_practices.analyze
      rails_best_practices.output
      LOGGER.info "analyzed"

      send_request(:result => File.read(output_file))
      LOGGER.info "request sent"
      "success"
    rescue Exception => e
      LOGGER.error e.message
      send_request(:error => e.message)
      "failure"
    ensure
      FileUtils.rm_rf(analyze_path)
    end
  end

  post "/configs" do
    File.open(config_file_path, "w+") do |file|
      file.write(params[:configs])
    end
  end

  def send_request(extra_params)
    http = Net::HTTP.new('railsbp.com', 443)
    http.use_ssl = true
    http.post("/sync_proxy", request_params.merge(extra_params).map { |key, value| "#{key}=#{value}" }.join("&"))
  end

  def request_params
    {
      :token => RAILSBP_CONFIG["token"],
      :repository_url => @payload["repository"]["url"],
      :last_commit => JSON.generate(@payload["commits"].last),
      :ref => @payload["ref"]
    }
  end

  def build_path
    RAILSBP_CONFIG["build_path"]
  end

  def build_name
    last_commit_id
  end

  def last_commit_id
    @payload["commits"].last["id"]
  end

  def config_file_path
    "#{build_path}/config/rails_best_practices.yml"
  end

  def repository_url
    "git@github.com:#{RAILSBP_CONFIG["github_name"]}.git"
  end

  def analyze_path
    "#{build_path}/#{build_name}"
  end

  def output_file
    "#{build_path}/output.json"
  end

  def template_file
    File.join(File.dirname(__FILE__), '..', 'assets', 'template.json.erb')
  end
end
