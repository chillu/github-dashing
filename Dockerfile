FROM ruby:2.1.9

# Install essential Linux packages
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    nodejs

WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile* /app/

# Speed up nokogiri install
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

RUN gem install bundler
RUN bundle install

COPY . /app
CMD bundle exec dashing start
