# slash-consonance

# Update 2018-09-10

Since it has rebranded, this project has been updated and renamed in turn to _slash-consonance_. This project used to be called _slash-bibliocloud_. 

## Upgrade considerations

You'll need to change your 'bibliocloud_token' config var in Heroku to 'consonance_token' when upgrading from slash-bibliocloud. Other than that you may also need to update your settings within Slack so the replies are posted using the new branding.

_Search Consonance from within Slack_

Slash-consonance lets you query your [Consonance](http://consonance.app/) data from within slack using a custom slash command integration.

Slash-consonance runs on a Heroku dyno that receives the slash commands from your team's slack, queries the Consonance API for the relevant information, processes the results and posts them back to Slack. It is a simple ruby application using the excellent [cksh_commander](https://github.com/openarcllc/cksh_commander) gem.

## Requirements

You'll need a Heroku account, an API key for querying the Consonance API, and admin access to your team's Slack.

You'll have to raise a support ticket with the Consonance team to request an API key.

For the manual installation you'll need git and the Heroku CLI installed.

## Manual Installation

Clone this repo and push it to a new Heroku application for yourself.

	git clone https://github.com/nickbarreto/slash-consonance.git
	cd slash-consonance
	heroku create <your-app-name>
	git remote add heroku
	git push heroku master

You can call your app anything you want, but I think your Slack team name plus "-slash-consonance" is a good option.

### Automatic Heroku Deploy

If you don't want to install git and muck around on the command line, you can click this handy button to deploy automatically to Heroku:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

As above, you'll need to choose a name and a region for your servers.

## Configuration

You need to do some configuration from within Slack:

Add a new custom integration to your team's Slack. Specifically, a slash command.

UPDATE: It looks like Slack have just changed how these are setup, and generally they want new slash commands to be added as Slack Apps. This isn't how this code is set up at the moment, so for now you should create you new slash command [here](https://my.slack.com/apps/A0F82E8CA-slash-commands). This app may be changed to conform to the new Slack App set up soon.

Fill in the required fields. Use something sensible for the command, such as '/bibliocloud'. The URL should point to the Heroku app you just created: `https://<yourappname>.herokuapp.com`. Method: `POST`. I gave the integration the same name and icon that we use for the Bibliocloud changes bot.

Press `Add Slash Command Integration`.

Set the token from the slash command as a config var in your Heroku app. You also need to set your Bibliocloud API token. Back in your terminal:

	heroku config:set SLACK_TOKEN=<your_slack_token>
	heroku config:set CONSONANCE_TOKEN=<your_consonance_token>

You can also set these on the web without using the Heroku CLI in your terminal. Go to [https://dashboard.heroku.com/apps/](https://dashboard.heroku.com/apps/), click your app, then go to `Settings` and click "Reveal Config Vars". You'll see both those variables in there and be able to edit them.

Once those are set, you're all done!

## Usage

You can now query your Bibliocloud data from within slack. Type in `/consonance [text to search]` and you'll get back a list of products that contain the words you searched in their title, along with their ISBNs. You can then use `/consonance isbn [an_isbn]` to get more information about one product. You can also search by publication date with `/consonance date yyyy-mm-dd`. Hooray!

Note: Heroku free dynos go to sleep after a certain amount of inactivity. If you make a query and you get an error, try it again in a moment after the dyno has woken up. If you want it to run 24/7, you can upgrade it to a Hobby Dyno for $7 a month.

## Contributing

All the commands are defined in the `/commands/consonance/command.rb` file. If you want to add any new subcommands, you can send them as pull requests for changes to that file.
