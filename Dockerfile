FROM ruby:4.0

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app
# Install exactly what Gemfile.lock pins; fail if it is missing or stale.
RUN bundle config set --local frozen true && bundle install

# data/ must exist before the chown so a named volume mounted there
# inherits appuser ownership instead of root's.
RUN mkdir -p /usr/src/app/data && useradd -m -u 1000 appuser && chown -R appuser:appuser /usr/src/app
USER appuser

EXPOSE 9292

ENTRYPOINT ["bundle", "exec", "rackup", "--host", "0.0.0.0"]
