require 'yaml'
require 'json'
require 'sinatra/base'
require 'git'
require 'rails_best_practices'
require 'typhoeus'

RAILSBP_CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'railsbp.yml'))[ENV['RACK_ENV']]

class Sinatra::Proxy < Sinatra::Base
  post RAILSBP_CONFIG["hook_path"] do
    begin
      return "not authenticate" unless RAILSBP_CONFIG["token"] == params[:token]

      payload = JSON.parse(params[:payload])
      return "skip" unless payload["ref"] =~ %r|#{RAILSBP_CONFIG["branch"]}$|

      FileUtils.mkdir_p(build_path) unless File.exist?(build_path)
      FileUtils.cd(build_path)
      g = Git.clone(repository_url, build_name)
      Dir.chdir(analyze_path) { g.reset_hard(last_commit_id(payload)) }
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
      FileUtils.rm_rf(analyze_path)

      Typhoeus::Request.post("http://railsbp.com/sync_proxy", :params => request_params(payload).merge({:result => File.read(output_file)}))
      "success"
    rescue => e
      puts e.message
      FileUtils.rm_rf(analyze_path) if File.exist?(analyze_path)
      Typhoeus::Request.post("http://railsbp.com/sync_proxy", :params => request_params(payload).merge({:error => e.inspect}))
      "failure"
    end
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
