require 'test_helper'

class FootballDataTest < ActiveSupport::TestCase
  def response(klass, code, body)
    res = klass.new('1.1', code, 'msg')
    res.instance_variable_set(:@read, true)
    res.body = body
    res
  end

  test 'returns parsed JSON on success' do
    ok = response(Net::HTTPOK, '200', '{"teams":[1,2]}')
    Net::HTTP.stub :start, ->(*_args, **_opts) { ok } do
      assert_equal({ 'teams' => [1, 2] }, FootballData.get('competitions/1/teams', season: 2026))
    end
  end

  test 'returns nil on an HTTP error' do
    failed = response(Net::HTTPInternalServerError, '500', 'oops')
    Net::HTTP.stub :start, ->(*_args, **_opts) { failed } do
      assert_nil FootballData.get('competitions')
    end
  end

  test 'returns nil on timeouts and network errors' do
    Net::HTTP.stub :start, ->(*_args, **_opts) { raise Net::OpenTimeout } do
      assert_nil FootballData.get('competitions')
    end
    Net::HTTP.stub :start, ->(*_args, **_opts) { raise SocketError } do
      assert_nil FootballData.get('competitions')
    end
  end

  test 'returns nil on invalid JSON' do
    garbage = response(Net::HTTPOK, '200', '<html>')
    Net::HTTP.stub :start, ->(*_args, **_opts) { garbage } do
      assert_nil FootballData.get('competitions')
    end
  end
end
