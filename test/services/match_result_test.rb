require 'test_helper'

class MatchResultTest < ActiveSupport::TestCase
  def api_match(status:, full: {}, extra: nil, pens: nil)
    score = { 'fullTime' => full }
    score['extraTime'] = extra if extra
    score['penalties'] = pens if pens
    { 'status' => status, 'score' => score }
  end

  test 'regular time result' do
    result = MatchResult.new(api_match(status: 'FINISHED', full: { 'home' => 2, 'away' => 1 }))
    assert_equal [2, 1], [result.mainscore1, result.mainscore2]
    assert_nil result.subscore1
    assert_nil result.penscore1
    assert result.finished?
    assert_not result.in_play?
  end

  test 'extra time is split from the 90 minute score' do
    result = MatchResult.new(api_match(status: 'FINISHED',
                                       full: { 'home' => 2, 'away' => 1 },
                                       extra: { 'home' => 1, 'away' => 0 }))
    assert_equal [1, 1], [result.mainscore1, result.mainscore2]
    assert_equal [2, 1], [result.subscore1, result.subscore2]
  end

  test 'penalties are split from extra time and the 90 minute score' do
    result = MatchResult.new(api_match(status: 'FINISHED',
                                       full: { 'home' => 6, 'away' => 4 },
                                       extra: { 'home' => 1, 'away' => 0 },
                                       pens: { 'home' => 4, 'away' => 3 }))
    assert_equal [1, 1], [result.mainscore1, result.mainscore2]
    assert_equal [2, 1], [result.subscore1, result.subscore2]
    assert_equal [4, 3], [result.penscore1, result.penscore2]
  end

  test 'in play and unscored matches' do
    live = MatchResult.new(api_match(status: 'IN_PLAY', full: { 'home' => 0, 'away' => 0 }))
    assert live.in_play?
    assert_not live.finished?
    unscored = MatchResult.new(api_match(status: 'FINISHED', full: { 'home' => nil, 'away' => nil }))
    assert_not unscored.scored?
    assert_not unscored.finished?
  end

  test 'attributes can be passed to Match#update' do
    result = MatchResult.new(api_match(status: 'FINISHED', full: { 'home' => 3, 'away' => 0 }))
    assert_equal %i[mainscore1 mainscore2 subscore1 subscore2 penscore1 penscore2], result.attributes.keys
  end
end
