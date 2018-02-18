FROM ruby:2.4.3

RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app
RUN bundle install

EXPOSE 9292

ENTRYPOINT ["rackup", "--host", "0.0.0.0"]
