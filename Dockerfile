FROM ruby:3.4.4 as base

RUN apt-get update -qq && apt-get install -y build-essential apt-utils libpq-dev nodejs

WORKDIR /app

RUN gem install bundler

COPY Gemfile* ./

RUN bundle install

ADD . /app

ARG DEFAULT_PORT 8088

EXPOSE ${DEFAULT_PORT}

CMD ["rails","server"]
