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

  post RAILSBP_CONFIG["hook_path"] do
    begin
      return "not authenticate" unless RAILSBP_CONFIG["token"] == params[:token]
      LOGGER.info "authenticated"

      payload = JSON.parse(params[:payload])
      return "skip" unless payload["ref"] =~ %r|#{RAILSBP_CONFIG["branch"]}$|
      LOGGER.info "match branch"

      FileUtils.mkdir_p(build_path) unless File.exist?(build_path)
      FileUtils.cd(build_path)
      g = Git.clone(repository_url, build_name, :depth => 10)
      Dir.chdir(analyze_path) { g.reset_hard(last_commit_id(payload)) }
      LOGGER.info "cloned"
      rails_best_practices = RailsBestPractices::Analyzer.new(analyze_path,
                                                              "format"         => "html",
                                                              "silent"         => true,
                                                              "output-file"    => output_file,
                                                              "with-github"    => true,
                                                              "github-name"    => RAILSBP_CONFIG["github_name"],
                                                              "last-commit-id" => last_commit_id(payload),
                                                              "template"       => template_file
                                                             )
      rails_best_practices.analyze
      rails_best_practices.output
      LOGGER.info "analyzed"
      FileUtils.rm_rf(analyze_path)

      send_request(payload, :result => File.read(output_file))
      LOGGER.info "request sent"
      "success"
    rescue => e
      LOGGER.error e.message
      FileUtils.rm_rf(analyze_path) if File.exist?(analyze_path)
      send_request(payload, :error => Marshal::dump(e))
      "failure"
    end
  end

  def send_request(payload, extra_params)
    http = Net::HTTP.new('railsbp.com', 443)
    http.use_ssl = true
    http.post("/sync_proxy", request_params(payload).merge(extra_params).map { |key, value| "#{key}=#{value}" }.join("&")
  end

  def request_params(payload)
    {
      :token => RAILSBP_CONFIG["token"],
      :repository_url => payload["repository"]["url"],
      :last_commit => payload["commits"].last,
      :ref => payload["ref"]
    }
  end

  def build_path
    RAILSBP_CONFIG["build_path"]
  end

  def build_name
    "railsbp_build"
  end

  def last_commit_id(payload)
    payload["commits"].last["id"]
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
