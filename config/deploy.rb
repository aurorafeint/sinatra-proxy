require 'bundler/capistrano'
$:.unshift(File.expand_path('./lib', ENV['rvm_path']))  # Add RVM's lib directory to the load path.
require "rvm/capistrano"                                # Load RVM's capistrano plugin.
set :rvm_ruby_string, 'ruby-1.9.2@sinatra-proxy'        # Or whatever env you want it to run in.
set :rvm_bin_path, "/usr/local/rvm/bin"

set :application, "railsp sinatra proxy"
set :repository,  "git@github.com:aurorafeint/sinatra-proxy.git"
set :ssh_options, { :forward_agent => true }

set :scm, :git
set :deploy_to, "/home/deploy/rails_apps/railsbp"
set :user, :deploy
set :use_sudo, false
set :runner, :deploy

role :web, "railsbp-prime-01.c43893.blueboxgrid.com"
role :app, "railsbp-prime-01.c43893.blueboxgrid.com"

after "deploy:update_code", "config:init"

namespace :config do
  task :init do
    run "ln -nfs #{shared_path}/config/railsbp.yml #{release_path}/config/railsbp.yml"
  end
end

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end
