# slash-bibliocloud

_Search Bibliocloud from within Slack_

Slash-bibliocloud lets you query your [Bibliocloud](http://bibliocloud.com/) data from within slack using a custom slash command intergration. 

Slash-bibliocloud runs on a heroku dyno that receives the slash commands from your team's slack, queries the Bibliocloud API for the relevant information, processes the results and posts them back to Slack. It is a simple ruby application using the excellent [cksh_commander](https://github.com/openarcllc/cksh_commander) gem.

## Requirements

You'll need a Heroku account, an authorisation token for querying the Bibliocloud API, and admin access to your team's Slack.

For the manual installation you'll need git and the Heroku CLI installed. 

## Manual Installation

Clone this repo and push it to a new Heroku application for yourself.

	git clone https://github.com/nickbarreto/slash-bibliocloud.git
	cd slash-bibliocloud
	heroku create <your-app-name>
	git remote add heroku
	git push heroku master

You can call your app anything you want, but I think your Slack team name plus "-slash-bibliocloud" is a good option.

### Automatic Heroku Deploy

If you don't want to install git and muck around on the command line, you can click this handy button to deploy automatically to Heroku:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

As above, you'll need to choose a name and a region for your servers.

## Configuration

You need to do some configuration from within Slack:

Add a new custom intergration to your team's Slack. Specifically, a slash command.

Fill in the required fields. Use something sensible for the command, such as '/bibliocloud'. The URL should point to the heroku app you just created: `https://<yourappname>.herokuapp.com`. Method: `POST`. I gave the intergration the same name and icon that we use for the Bibliocloud changes bot.

Press `Add Slash Command Intergration`.

Set the token from the slash command as a config var in your heroku app. You also need to set your Bibliocloud API token. Back in your terminal:

	heroku config:set SLACK_TOKEN=<your_slack_token>
	heroku config:set BIBLIOCLOUD_TOKEN=<your_bibliocloud_token>

That's it, you're all set up!

## Usage

You can now query your Bibliocloud data from within slack. Type in `/bibliocloud [text to search]` and you'll get back a list of books that contain the words you searched in their title, along with their ISBNs. You can then use `/bibliocloud isbn [an_isbn]` to get more information about one book. You can also search by publication date with `/bibiliocloud date yyyy-mm-dd`. Hooray!

Note: Heroku free dynos go to sleep after a certain amount of inactivity. If you make a query and you get an error, try it again in a moment after the dyno has woken up. If you want it to run 24/7, you can upgrade it to a Hobby Dyno for $7 a month.

## Contributing

All the commands are defined in the `/commands/bibliocloud/command.rb` file. If you want to add any new subcommands, you can send them as pull requests for changes to that file.