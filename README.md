# Github Contribution Dashboard

Dashboard to monitor the health of github projects based on their contribution statistics.
Uses data gathered by [githubarchive.org](http://githubarchive.org), and views the
data through [Dashing](http://shopify.github.com/dashing), a Ruby web application
built on the [Sinatra](http://www.sinatrarb.com) framework.

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

## Usage

Finally, start the dashboard server:

	dashing start

Now you can browse the dashboard at `http://localhost:3030/default`.