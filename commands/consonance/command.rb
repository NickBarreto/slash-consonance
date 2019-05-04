require 'cksh_commander'
require 'json'
require 'httparty'
require 'date'
require 'uri'

module Consonance
  class Command < CKSHCommander::Command
    set token: ENV['SLACK_TOKEN'] # This is needed for authentication into slack, and should be added as a config var

    def consonance_api_call(text, search_type)
      consonance_token = ENV['CONSONANCE_TOKEN'] #needed for the header authorisation
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
      data = HTTParty.get("https://web.consonance.app/api/products.json?q[#{query_string}]=#{search_text}", headers: {"Authorization" => "Token token=#{consonance_token}"})
      return data
    end

    def create_response(data) # Parses the data returned from consonance_api_call
      # Generally to be used to assign a value to set_response_text, but if a single
      # product is returned it should be used to assign a value to add_response_attachment
      if data["products"].length == 0 # Needed if the query has no results
        return "I didn't find anything, sorry. Could you change your search and try again?"
      end
      if data["products"].length == 1 # Only one match, return specific information
        work_id = data["products"].first["work_id"]
        title = data["products"].first["full_title"]
        author = data["products"].first["authorship"]
        isbn = data["products"].first["isbn"].gsub('-', '')
        # Ingesting and parsing the date as a date object
        pubdate = data["products"].first["pub_date"]
        pubdate = Date.parse(pubdate)
        pubdate_as_text = pubdate.strftime('%d %b %Y')
        territories = "World"
        unless data["products"].first["rights_not_available_countries"].empty?
          # The .join() method returns a string rather than an array
          territories_excluded = data["products"].first["rights_not_available_countries"].join(", ")
          territories << " excluding #{territories_excluded}"
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
          description = "(There is no description in Consonance)"
        else
          if data["products"].first["marketingtexts"].find{ |x| x['code'] == "01"}["external_text"].empty? == true
            description = "(There is no main description for this title in Consonance)"
          else
            description = data["products"].first["marketingtexts"].find{ |x| x['code'] == "01"}["external_text"]
          end
        end
        # Craft the response JSON as a ruby hash
        response = {}.tap do |response_hash|
          response_hash["pretext"] = "This search matched _#{title}_ in Consonance."
          response_hash["title"] = title
          response_hash["title_link"] = "https://web.consonance.app/works/#{work_id}"
          response_hash["author_name"] = author
          response_hash["thumb_url"] = cover
          response_hash["fields"] = Array.new.tap do |field|
            field << {
              "title" => "ISBN",
              "value" => isbn,
              "short" => true
            }
            field << {
              "title" => "Publication Date",
              "value" => pubdate_as_text,
              "short" => true
            }
            field << {
              "title" => "GBP Price",
              "value" => "£#{price}",
              "short" => true
            }
            field << {
              "title" => "Territories",
              "value" => territories,
              "short" => true
            }
            field << {
              "title" => "Description",
              "value" => description,
              "short" => false
            }
          end
          response_hash["footer"] = "Consonance API"
          response_hash["footer_icon"] = "https://web.consonance.app/favicon-32x32.png"
          response_hash["mrkdwn_in"] = ["pretext"]
        end
        return response
      end
      if  data["products"].length > 1 # More than one match, return only general info
        results = data["products"].map { |p| { title: p["full_title"], isbn: p["isbn"].gsub("-", ""), work_id: p["work_id"] } } # Pulls out just the title and ISBN into an array of hashes, while removing hyphens from the ISBN
        response = results.collect { |p| "#{p[:title]}, which has the ISBN #{p[:isbn]}: https://web.consonance.app/works/#{p[:work_id]}" } #Create the response text
        response = response.join("\n")
        return response
      end
    end

    # Search by title, the basic command
    # Searches for titles containing the text passed in. Can return
    # multiple matches as this is a general search.
    # SLACK: /consonance text
    desc "[text to search by title]", "Shows you books which contain the words you enter in their title."
    def ___(text)
      debug!
      # Query the Consonance API with consonance_api_call method defined above
      data = consonance_api_call("#{text}","title")
      # Parse the data pulling out elements to return
      response = create_response(data)
      # Send message to Slack depending on whether there is more than one result or not
      if data["products"].length == 0
        set_response_text(response)
      end
      if data["products"].length > 1
        set_response_text("Consonance has these books with ‘#{text}’ in the title:\n#{response}")
      end
      if data["products"].length == 1
        add_response_attachment(response)
      end
    end

    # Search by ISBN subcommand
    # Since this must return only one result or no matches, it should return
    # lots of details about the matched title.
    # SLACK: /consonance isbn xxxxxxxxxxxxx
    desc "isbn [ISBN to search for]", "Shows you Consonance data for the title with a matching ISBN."
    def isbn(text)
      # Query the Consonance API with consonance_api_call method defined above
      data = consonance_api_call("#{text}","isbn")
      response = create_response(data)
      # Send message to Slack depending on whether there is more than one result or not
      if data["products"].length == 1
        add_response_attachment(response)
      else
        set_response_text(response)
      end
    end

    # Search by pub date subcommand
    # Will most likely return many matches, so only posts general details.
    # SLACK: /consonance date yyyy-mm-dd
    desc "date [YYYY-MM-DD]", "Shows you which books in Consonance publish on a date in yyyy-mm-dd."
    def date(text)
      # Query the Consonance API
      data = consonance_api_call("#{text}","date")
      response = create_response(data)
      # Send message to Slack depending on whether there is more than one result or not
      if data["products"].length == 0
        set_response_text(response)
      end
      if data["products"].length > 1
        set_response_text("Consonance has these books publishing on #{text}:\n#{response}")
      end
      if data["products"].length == 1
        add_response_attachment(response)
      end
    end
  end
end
