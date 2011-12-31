require 'rubygems'
require 'bundler'

Bundler.require(:default, :production)

ENV['RACK_ENV'] = 'production'
require './sinatra/proxy.rb'
run Sinatra::Proxy

