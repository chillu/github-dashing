# Github Contribution Dashboard

Dashboard to monitor the health of github projects based on their contribution statistics.
Uses data gathered by [githubarchive.org](http://githubarchive.org), and views the
data through [Dashing](http://shopify.github.com/dashing), a Ruby web application
built on the [Sinatra](http://www.sinatrarb.com) framework.
The dashboard widgets support aggregate statistics of multiple repos or even
all repos within an organization.

## Setup

First install the required depenncies through `bundle install`.

The data is retrieved through Google's [BigQuery API](https://developers.google.com/bigquery/),
which requires OAuth2 authentication against your Google account.

 1. [Sign up](https://developers.google.com/bigquery/sign-up) for the service
 1. Go to the [Google APIs Console](https://code.google.com/apis/console) and open your 'API Project'.
 1. Click API Access.
 1. Click Create an OAuth 2.0 client ID.
 1. In the Product Name field enter "Github Dashboard" and click "next"
 1. Choose application type "Service account" and click "create"
 1. Download the private key, and store it in `jobs/config/privatekey.p12
 1. Copy `jobs/config/config.sample.yml` to `jobs/config/config.yml`
 1. Insert "Product name" (`project_id`) and "Client ID" (`issuer`) values into `config.yml`

Now you just need to configure which repos and orgs to show on github.

Example `config.yml` for a single repo:

	orgas: ['silverstripe']
	repos: ['silverstripe-cms']

Example for all repos in multiple orgas:

	orgas: ['silverstripe', 'silverstripe-labs']
	repos: []

## Usage

Finally, start the dashboard server:

	dashing start

Now you can browse the dashboard at `http://localhost:3030/default`.

## Tasks and Data Usage

The Dashing jobs query for their data whenever the server is started,
and then with a frequency of 1h by default. You can set this higher,
but keep in mind that Google's BigQuery API has a request limit of 10k/req/day.
The githubarchive.org crawler also imports new data with a short [delay](https://github.com/igrigorik/githubarchive.org/blob/master/crawler/tasks.cron). Given these constraints, realtime statistics aren't feasible.