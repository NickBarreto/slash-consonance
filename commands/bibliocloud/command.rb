require "cksh_commander"
require "json"
require "httparty"
require 'date'
require 'uri'

module Bibliocloud
  class Command < CKSHCommander::Command
    set token: ENV['SLACK_TOKEN'] # This is needed for authentication into slack, and should be added as a config var

    def bibliocloud_api_call(text,search_type)
      bibliocloud_token = ENV['BIBLIOCLOUD_TOKEN'] #needed for the header authorisation
      if search_type == 'title'
        # [work_title_cont] means the API will return results that contain in their title
        # the words passed in from the slash command.
        query_string = 'work_title_cont'
        search_text = URI.escape(text) # Sanitise user input for URLs
      end
      if search_type == 'isbn'
        query_string = 'isbn_eq'
        # [isbn_eq] means the API will return results match isbn of a book.
        search_text = text.gsub('-', '') # Remove hyphens from ISBN sent from Slack if there are any
      end
      if search_type == 'date'
        query_string = 'pub_date_eq'
        # [pub_date_eq] means the API will return results based on the pub date of a book.
        if text == 'today'
          date = DateTime.now # Returns the date and time today
          search_text = date.strftime('%Y-%m-%d') # Converts today's date and time object to string 'yyyy-mm-dd'
        else
          search_text = text
        end
      end
      data = HTTParty.get("https://app.bibliocloud.com/api/products.json?q[#{query_string}]=#{search_text}", headers: {"Authorization" => "Token token=#{bibliocloud_token}"})
      return data
    end

    def create_response(data) # Parses the data returned from bibliocloud_api_call
      # Generally to be used to assign a value to set_response_text, but if a single
      # product is returned it should be used to assign a value to add_response_attachment
      if data["products"].length == 0 # Needed if the query has no results
        return "I didn't find anything, sorry. Could you change your search and try again?"
      end
      if data["products"].length == 1 # Only one match, return specific information
        work_id = data["products"].first["work_id"]
        title = data["products"].first["full_title"]
        author = data["products"].first["authorship"]
        # Ingesting and parsing the date as a date object
        pubdate = data["products"].first["pub_date"]
        pubdate = Date.parse(pubdate)
        pubdate_as_text = pubdate.strftime('%d %b %Y')
        if data["products"].first["rights_not_available_countries"].empty? == true
          territories_excluded = "None"
        else
          # The .join() method returns a string rather than an array
          territories_excluded = data["products"].first["rights_not_available_countries"].join(", ")
        end
        # Selecting the cover is a bit of a complex path
        if data["products"].first["supportingresources"].empty? == true
          cover = "none"
        else
          cover = data["products"].first["supportingresources"].first["style_urls"].find{ |x| x["style"] == "jpg_rgb_0050w" }["url"]
        end
        # Selecting the price
        if data["products"].first["prices"].empty? == true
          price = "(None found)"
        else
          price = data["products"].first["prices"].find{ |x| x["currency_code"] == "GBP" && x["price_qualifier"] == "05"}["price_amount"]
        end
        # Select the description
        if data["products"].first["marketingtexts"].empty? == true
          description = "(There is no description in Bibliocloud)"
        else
          if data["products"].first["marketingtexts"].find{ |x| x['code'] == "01"}["external_text"].empty? == true
            description = "(There is no main description for this title in Bibliocloud)"
          else
            description = data["products"].first["marketingtexts"].find{ |x| x['code'] == "01"}["external_text"]
          end
        end
        # Craft the response JSON as a ruby hash
        response = {
          "pretext" => "This ISBN is for _#{title}_ according to Bibliocloud.",
          "title" => "#{title}",
          "title_link" => "https://app.bibliocloud.com/works/#{work_id}",
          "author_name" => "#{author}",
          "thumb_url" => "#{cover}",
          "fields" => [
            {
              "title" => "ISBN",
              "value" => "#{text}",
              "short" => true
            },
            {
              "title" => "Publication Date",
              "value" => "#{pubdate_as_text}",
              "short" => true
            },
            {
              "title" => "GBP Price",
              "value" => "£#{price}",
              "short" => true
            },
            {
              "title" => "Territories Excluded",
              "value" => "#{territories_excluded}",
              "short" => true
            },
            {
              "title" => "Description",
              "value" => "#{description}",
              "short" => false
            }
          ],
          "footer" => "Bibliocloud API",
          "footer_icon" => "https://app.bibliocloud.com/favicon-32x32.png",
          "mrkdwn_in" => ["pretext"]
        }
        return response
      end
      if  data["products"].length > 1 # More than one match, return only general info
        results = data["products"].map { |p| { title: p["full_title"], isbn: p["isbn"].gsub("-", "") } } # Pulls out just the title and ISBN into an array of hashes, while removing hyphens from the ISBN
        response = results.collect { |p| "#{p[:title]}, which has the ISBN #{p[:isbn]}" } #Create the response text
        response = response.join("\n")
        return response
      end
    end

    # Search by title, the basic command
    # Searches for titles containing the text passed in. Can return
    # multiple matches as this is a general search.
    # SLACK: /bibliocloud text
    desc "[text to search by title]", "Shows you books which contain the words you enter in their title."
    def ___(text)
      # Query the Bibliocloud API with bibliocloud_api_call method defined above
      data = bibliocloud_api_call("#{text}","title")
      # Parse the data pulling out elements to return
      response = create_response(data)
      # Send message to Slack depending on whether there is more than one result or not 
      if data["products"].length == 0
        set_response_text(response)
      end
      if data["products"].length > 1
        set_response_text("Bibliocloud has these books with ‘#{text}’ in the title:\n#{response}")
      end
      if data["products"].length == 1
        add_response_attachment(response.to_json)
      end
    end

    # Search by ISBN subcommand
    # Since this must return only one result or no matches, it should return
    # lots of details about the matched title.
    # SLACK: /bibliocloud isbn xxxxxxxxxxxxx
    desc "isbn [ISBN to search for]", "Shows you Bibliocloud data for the title with a matching ISBN."
    def isbn(text)
      # Query the Bibliocloud API with bibliocloud_api_call method defined above
      data = bibliocloud_api_call("#{text}","isbn")
      if data["products"].empty? == true # Needed if there are no results
        set_response_text("I didn't find anything, sorry. Could you change your search and try again?")
      else # Pull out info from the Ruby hash returned by Httparty
        work_id = data["products"].first["work_id"]
        title = data["products"].first["full_title"]
        author = data["products"].first["authorship"]
        # Ingesting and parsing the date as a date object
        pubdate = data["products"].first["pub_date"]
        pubdate = Date.parse(pubdate)
        pubdate_as_text = pubdate.strftime('%d %b %Y')
        if data["products"].first["rights_not_available_countries"].empty? == true
          territories_excluded = "None"
        else
          # The .join() method returns a string rather than an array
          territories_excluded = data["products"].first["rights_not_available_countries"].join(", ")
        end
        # Selecting the cover is a bit of a complex path
        if data["products"].first["supportingresources"].empty? == true
          cover = "none"
        else
          cover = data["products"].first["supportingresources"].first["style_urls"].find{ |x| x["style"] == "jpg_rgb_0050w" }["url"]
        end
        # Selecting the price
        if data["products"].first["prices"].empty? == true
          price = "(None found)"
        else
          price = data["products"].first["prices"].find{ |x| x["currency_code"] == "GBP" && x["price_qualifier"] == "05"}["price_amount"]
        end
        # Select the description
        if data["products"].first["marketingtexts"].empty? == true
          description = "(There is no description in Bibliocloud)"
        else
          if data["products"].first["marketingtexts"].find{ |x| x['code'] == "01"}["external_text"].empty? == true
            description = "(There is no main description for this title in Bibliocloud)"
          else
            description = data["products"].first["marketingtexts"].find{ |x| x['code'] == "01"}["external_text"]
          end
        end
# Escape the HTML entities as per Slack's requirements
description = description.gsub('<', '&lt;').gsub('>', '&gt;')
        # Send the response to Slack using the attachment format: https://api.slack.com/docs/message-attachments.
        add_response_attachment({
          "pretext": "This ISBN is for _#{title}_ according to Bibliocloud.",
          "title": "#{title}",
          "title_link": "https://app.bibliocloud.com/works/#{work_id}",
          "author_name": "#{author}",
          "thumb_url": "#{cover}",
          "fields": [
            {
              "title": "ISBN",
              "value": "#{text}",
              "short": true
            },
            {
              "title": "Publication Date",
              "value": "#{pubdate_as_text}",
              "short": true
            },
            {
              "title": "GBP Price",
              "value": "£#{price}",
              "short": true
            },
            {
              "title": "Territories Excluded",
              "value": "#{territories_excluded}",
              "short": true
            },
            {
              "title": "Description",
              "value": "#{description}",
              "short": false
            }
          ],
          "footer": "Bibliocloud API",
          "footer_icon": "https://app.bibliocloud.com/favicon-32x32.png",
          "mrkdwn_in": ["pretext"]
        })
      end
    end

    # Search by pub date subcommand
    # Will most likely return many matches, so only posts general details.
    # SLACK: /bibliocloud date yyyy-mm-dd
    desc "date [YYYY-MM-DD]", "Shows you which books in Bibliocloud publish on a date in yyyy-mm-dd."
    def date(text)
      # Query the Bibliocloud API
      data = bibliocloud_api_call("#{text}","date")
      if data["products"].empty? == true # Needed if there are no results
        set_response_text("I didn't find anything, sorry. Could you change your search and try again?")
      else
        results = data["products"].map { |p| { title: p["full_title"], isbn: p["isbn"].gsub("-", "") } } # Pulls out just the title and ISBN into an array of hashes, while removing hyphens from the ISBN
        response = results.collect { |p| "#{p[:title]}, which has the ISBN #{p[:isbn]}" } #Create the response text
        response = response.join("\n") # Join each response with a newline as the separator
        set_response_text("Bibliocloud has these books publishing on #{text}:\n#{response}")
      end
    end
  end
end