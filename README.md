# Github Contribution Dashboard

Dashboard to monitor the health of github projects based on their contribution statistics.

 - Uses data gathered by [githubarchive.org](http://githubarchive.org), and views the
data through [Dashing](http://shopify.github.com/dashing), a Ruby web application
built on the [Sinatra](http://www.sinatrarb.com) framework.
 - Widgets support aggregate statistics of multiple repos or even all repos within an organization.
 - Easy hosting through [Heroku](http://heroku.com)

![Preview](assets/images/preview.png?raw=true)

## Setup

First install the required depenncies through `bundle install`.

The project is configured through environment variables.
Copy the `.env.sample` configuration file to `.env`.

The data is retrieved through Google's [BigQuery API](https://developers.google.com/bigquery/),
which requires OAuth2 authentication against your Google account.

 1. [Sign up](https://developers.google.com/bigquery/sign-up) for the service
 1. Go to the [Google APIs Console](https://code.google.com/apis/console) and open your 'API Project'.
 1. Click API Access.
 1. Click Create an OAuth 2.0 client ID.
 1. In the Product Name field enter "Github Dashboard" and click "next"
 1. Choose application type "Service account" and click "create"
 1. Download the private key, and store it in `privatekey.p12`
 2. Convert the private key through `openssl pkcs12 -in privatekey.p12 -nocerts -nodes`
 3. Insert the resulting key into `GOOGLE_KEY` and you `GOOGLE_SECRET` in `.env` (replacing all newlines with `\n`)
 1. Insert "Product name" (`GOOGLE_PROJECT_ID`) and "Client ID" (`GOOGLE_ISSUER`) values into `.env`

Now you just need to configure which repos and orgs to show on github.

Example `config.yml` for a single repo:

	ORGAS=
	REPOS=silverstripe/silverstripe-cms

Example for all repos in multiple orgas:

	ORGAS=silverstripe,silverstripe-labs
	REPOS=

## Usage

Finally, start the dashboard server:

	dashing start

Now you can browse the dashboard at `http://localhost:3030/default`.

## Tasks and Data Usage

The Dashing jobs query for their data whenever the server is started,
and then with a frequency of 1h by default. You can set this higher,
but keep in mind that Google's BigQuery API has a request limit of 10k/req/day.
The githubarchive.org crawler also imports new data with a short [delay](https://github.com/igrigorik/githubarchive.org/blob/master/crawler/tasks.cron). Given these constraints, realtime statistics aren't feasible.

## Heroku Deployment

Since Dashing is simply a Sinatra Rack app under the hood, deploying is a breeze. 
It takes around 30 seconds to do :) 

First, [sign up](https://id.heroku.com/signup) for the free service.
[Download](https://devcenter.heroku.com/articles/quickstart) the dev tools
and install them with your account credentials.

Due to a bug in config pushing on Heroku, its important to leave all single-line values in `.env` unquoted.

How you're ready to add your app to Heroku:

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

Heroku mangles the `GOOGLE_KEY` newlines, so we need to push it separately without `\n` chars:

	heroku config:set GOOGLE_KEY="-----BEGIN PRIVATE KEY-----
	MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAKdV4u/5qVxi3tIZ
	...
	Hb4URYZSOiBB
	-----END PRIVATE KEY-----"

