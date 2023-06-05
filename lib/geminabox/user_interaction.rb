# Change rubygems progress reporter to now overflow the terminal with dots.
Gem::StreamUI::SimpleProgressReporter.class_eval do
  # Output around 50 progress dots.
  def updated(*_)
    @count += 1
    modulus = [@total / 50, 1].max
    @out.print "." if (@count % modulus).zero?
    @out.flush
  end
end
