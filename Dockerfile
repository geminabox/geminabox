FROM ruby:3.4

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app
# rubygems-generate_index is required on Ruby 3.3+ (Gem::Indexer was
# extracted from RubyGems). The server will refuse to start without it.
RUN gem install rubygems-generate_index && bundle install

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /usr/src/app
USER appuser

EXPOSE 9292

ENTRYPOINT ["rackup", "--host", "0.0.0.0"]
