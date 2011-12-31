require 'rubygems'
require 'bundler'

Bundler.require

require './sinatra/proxy.rb'
run Sinatra::Proxy

