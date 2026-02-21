FROM ruby:4.0

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app
RUN bundle install

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /usr/src/app
USER appuser

EXPOSE 9292

ENTRYPOINT ["rackup", "--host", "0.0.0.0"]
