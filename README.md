# Github Contribution Dashboard

[![Build Status](https://travis-ci.org/chillu/github-dashing.png?branch=master)](https://travis-ci.org/chillu/github-dashing)

Dashboard to monitor the health of github projects based on their contribution statistics.

 - Aggregates usage data across multiple repos from the Github API
 - Views the data through [Dashing](http://shopify.github.com/dashing), a Ruby web application
built on the [Sinatra](http://www.sinatrarb.com) framework.
 - Widgets support aggregate statistics of multiple repos or even all repos within an organization.
 - A leaderboard aggregates a score for the last 30 days on each contributor
 - Easy hosting through [Heroku](http://heroku.com)

![Preview](assets/images/preview.png?raw=true)

## Setup

### Generic Configuration

First install the required dependencies through `bundle install`.

The project is configured through environment variables.
Copy the `.env.sample` configuration file to `.env`.

 * `ORGAS`: Organizations (required). Separate multiple by comma. Will use all repos unless filtered in REPOS. 
   Example: `silverstripe,silverstripe-labs`
 * `REPOS`: # Repositories (optional). Separate multiple by comma. If used alongsize `ORGAS`, the logic will add
   all mentioned repos to the ones retrieves from `ORGAS`.
   Example: `silverstripe/silverstripe-framework,silverstripe/silverstripe-cms`
 * `SINCE`: Date string, or relative time parsed through [http://guides.rubyonrails.org/active_support_core_extensions.html](ActiveSupport). Example: `12.months.ago.beginning_of_month`, `2012-01-01`
 * `GITHUB_LOGIN`: Github authentication is optional, but recommended
 * `GITHUB_OAUTH_TOKEN`: See above
 * `LEADERBOARD_WEIGHTING`: Comma-separated weighting pairs influencing the multiplication of values
   used for the leaderboard widget score.
   Example: `commits_additions_max=200,commits_additions_loc_threshold=1000,commits_deletions_max=100,commits_deletions_loc_threshold=1000`
 * `LEADERBOARD_EDITS_WEIGHTING`: Comma-separated weighting pairs influencing the leaderboard widget scores based on lines of code added and deleted. The `max` and `threshold` values ensure the scores stay in reasonable bounds, and don't bias massive edits or additions of third party libraries to the codebase over other metrics. Note that the metrics are collected from the "default branch" in Github only.
   Example: `issues_opened=5,issues_closed=5,pull_requests_opened=10,pull_requests_closed=5,pull_request_comments=1,issue_comments=1,commit_comments=1,commits=20`
 * `TRAVIS_BRANCH_BLACKLIST`: A blacklist of branches ignored by repo, as a JSON string.
   This is useful to ignore old branches which no longer have active builds.
   Example: `{"silverstripe-labs/silverstripe-newsletter":["0.3","0.4"]}`

You can also specify a custom env file through setting a `DOTENV_FILE` environment variable first.
This is useful if you want to have version controlled defaults (see `.env.silverstripe`).

### Custom Configuration

The dashboard is used by the [SilverStripe CMS](http://silverstripe.org) project,
some of the functionality is specific to this use case. Simply leave out the configuration values
in case you're use case is different.

 * `FORUM_STATS_URL`: Absolute URL returning JSON data for forum statistics such as "unanswered posts"

### Github API Access

The dashboard uses the public github API, which doesn't require authentication.
Depending on how many repositories you're showing, hundreds of API calls might be necessary,
which can quickly exhaust the API limitations for unauthenticated use.

In order to authenticate, create a new [API Access Token](https://github.com/settings/applications)
on your github.com account, and add it to the `.env` configuration:

	GITHUB_LOGIN=your_login
	GITHUB_OAUTH_TOKEN=2b0ff00...................

## Usage

Finally, start the dashboard server:

	dashing start

Now you can browse the dashboard at `http://localhost:3030/default`.

## Tasks

The Dashing jobs query for their data whenever the server is started, and then with a frequency of 1h by default. 

## Heroku Deployment

Since Dashing is simply a Sinatra Rack app under the hood, deploying is a breeze. 
It takes around 30 seconds to do :) 

First, [sign up](https://id.heroku.com/signup) for the free service.
[Download](https://devcenter.heroku.com/articles/quickstart) the dev tools
and install them with your account credentials.

Due to a bug in config pushing on Heroku, its important to leave all single-line values in `.env` unquoted.

Now you're ready to add your app to Heroku:

	# Create a git repo for your project, and add your files.
	git init
	git add .
	git commit -m "My beautiful dashboard"

	# Create the application on Heroku 
	heroku apps:create myapp

	# Push the application to Heroku
	git push heroku master

	# Push your `.env` configuration
	heroku plugins:install git://github.com/ddollar/heroku-config.git
	heroku config:push

## Logging through Sentry

The project has optional [Sentry](http://getsentry.com) integration for logging exceptions.
Its particularly useful to capture Github API errors, e.g. when a project has been renamed.
To use it, configure your `SENTRY_DSN` in `.env` ([docs](https://getsentry.com/docs/)).
You'll need to sign up to Sentry to receive a valid DSN.