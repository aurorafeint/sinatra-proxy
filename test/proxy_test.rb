require 'sinatra/proxy'
require 'test/unit'
require 'rack/test'
require 'webmock/test_unit'

class Sinatra::ProxyTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Proxy
  end

  def setup
    stub_http_request(:post, "http://railsbp/com/sync_proxy")
  end

  def test_hook_without_token
    post "/"
    assert_equal "not authenticate", last_response.body
  end

  def test_hook_with_wrong_token
    post "/", :token => "9876543210"
    assert_equal "not authenticate", last_response.body
  end

  def test_hook_with_not_match_branch
    post "/", :token => "1234567890", :payload => payload_body
    assert_equal "skip", last_response.body
  end

  def test_hook
    post "/", :token => "1234567890", :payload => payload_body.sub("develop", "master")
    assert_equal "success", last_response.body
  end

  def payload_body
    body = <<-EOF
    {
      "before": "a6ab010bc21151e238c73d5229c36892d51c2d4f",
      "repository": {
        "url": "https://github.com/railsbp/rails-bestpractices.com",
        "name": "rails-bestpractice.com",
        "description": "rails-bestpractices.com",
        "watchers": 64,
        "forks": 14,
        "private": 0,
        "owner": {
          "email": "flyerhzm@gmail.com",
          "name": "Richard Huang"
        }
      },
      "commits": [
        {
          "id": "af9718a9bee64b9bbbefc4c9cf54c4cc102333a8",
          "url": "https://github.com/railsbp/rails-bestpractices.com/commit/af9718a9bee64b9bbbefc4c9cf54c4cc102333a8",
          "author": {
            "email": "flyerhzm@gmail.com",
            "name": "Richard Huang"
          },
          "message": "fix typo in .travis.yml",
          "timestamp": "2011-12-25T18:57:17+08:00",
          "modified": [".travis.yml"]
        },
        {
          "id": "473d12b3ca40a38f12620e31725922a9d88b5386",
          "url": "https://github.com/railsbp/rails-bestpractices.com/commit/473d12b3ca40a38f12620e31725922a9d88b5386",
          "author": {
            "email": "flyerhzm@gmail.com",
            "name": "Richard Huang"
          },
          "message": "copy config yaml files for travis",
          "timestamp": "2011-12-25T20:36:34+08:00"
        }
      ],
      "after": "473d12b3ca40a38f12620e31725922a9d88b5386",
      "ref": "refs/heads/develop"
    }
    EOF
  end
end
