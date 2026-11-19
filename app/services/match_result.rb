class MatchResult
  attr_reader :status, :mainscore1, :mainscore2, :subscore1, :subscore2, :penscore1, :penscore2

  def initialize(api_match)
    @status = api_match['status']
    score = api_match['score'] || {}
    full = score['fullTime'] || {}
    extra = score['extraTime'] || {}
    pens = score['penalties'] || {}
    @mainscore1, @subscore1 = split(full['home'], extra['home'], pens['home'])
    @mainscore2, @subscore2 = split(full['away'], extra['away'], pens['away'])
    @penscore1 = pens['home']
    @penscore2 = pens['away']
  end

  def scored?
    !mainscore1.nil? && !mainscore2.nil?
  end

  def in_play?
    status == 'IN_PLAY' && scored?
  end

  def finished?
    status == 'FINISHED' && scored?
  end

  def attributes
    {
      mainscore1: mainscore1, mainscore2: mainscore2,
      subscore1: subscore1, subscore2: subscore2,
      penscore1: penscore1, penscore2: penscore2
    }
  end

  private

  def split(full, extra, pens)
    return [nil, nil] if full.nil?
    main = full - extra.to_i - pens.to_i
    [main, extra.nil? ? nil : main + extra]
  end
end
