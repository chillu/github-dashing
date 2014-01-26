# Github Contribution Dashboard

[![Build Status](https://travis-ci.org/chillu/github-dashing.png?branch=master)](https://travis-ci.org/chillu/github-dashing)

Dashboard to monitor the health of github projects based on their contribution statistics.

 - Aggregates usage data across multiple repos from the Github API
 - Views the data through [Dashing](http://shopify.github.com/dashing), a Ruby web application
built on the [Sinatra](http://www.sinatrarb.com) framework.
 - Widgets support aggregate statistics of multiple repos or even all repos within an organization.
 - A leaderboard aggregates a score for the last 30 days on each contributor
 - Optionally sses data gathered by [githubarchive.org](http://githubarchive.org)
 - Easy hosting through [Heroku](http://heroku.com)

![Preview](assets/images/preview.png?raw=true)

## Setup

### Configuration

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
   Example: `issues_opened=5,issues_closed=5,pull_requests_opened=10,pull_requests_closed=5,pull_request_comments=1,issue_comments=1,commit_comments=1,commits=20`

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

## BigQuery Usage

The project initially relied on the [githubarchive.org](http://githubarchive.org)
project, which aggregates Github event data in Google's [BigQuery](https://developers.google.com/bigquery/).
This approach turned out to be infeasible (see quota comments below), but can still be enabled.

Note: The githubarchive.org crawler imports new data with a short 
[delay](https://github.com/igrigorik/githubarchive.org/blob/master/crawler/tasks.cron). 
Given these constraints, realtime statistics aren't feasible.

### API Access

*CAUTION: QUERIES A BILLABLE SERVICE WHEN ENABLED*

Due to the size of the githubarchive.org dataset (70GB+),
even simple queries will consume at least 6GB of your query quota.
Given the free BigQuery quota is just 100GB, this doesn't get you very far.

Using BigQuery requires OAuth2 authentication against your Google account.

 1. [Sign up](https://developers.google.com/bigquery/sign-up) for the service
 1. Go to the [Google APIs Console](https://code.google.com/apis/console) and open your 'API Project'.
 1. Click API Access.
 1. Click Create an OAuth 2.0 client ID.
 1. In the Product Name field enter "Github Dashboard" and click "next"
 1. Choose application type "Service account" and click "create"
 1. Download the private key, and store it in `privatekey.p12`
 1. Convert the private key through `openssl pkcs12 -in privatekey.p12 -nocerts -nodes`
 1. Insert the resulting key into `GOOGLE_KEY` and you `GOOGLE_SECRET` in `.env` (replacing all newlines with `\n`)
 1. Insert "Product name" (`GOOGLE_PROJECT_ID`) and "Client ID" (`GOOGLE_ISSUER`) values into `.env`

### Configuration and Deployment

The following configuration variables are required for BigQuery usage:

 * `GOOGLE_KEY`: Converted P12 key downloaded from Google (see below for conversion instructions)
 * `GOOGLE_SECRET`: Secret from your [https://code.google.com/apis/console](Google API Console) (defaults to 'notasecret')
 * `GOOGLE_ISSUER`: "Email address" from your [https://code.google.com/apis/console](Google API Console)
 * `GOOGLE_PROJECT_ID`: "Product name" from your [https://code.google.com/apis/console](Google API Console)

Heroku mangles the `GOOGLE_KEY` newlines, so we need to push it separately without `\n` chars:

	heroku config:set GOOGLE_KEY="-----BEGIN PRIVATE KEY-----
	MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAKdV4u/5qVxi3tIZ
	...
	Hb4URYZSOiBB
	-----END PRIVATE KEY-----"