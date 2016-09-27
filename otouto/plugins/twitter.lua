local twitter = {}

function twitter:init(config)
	if not cred_data.tw_consumer_key then
		print('Missing config value: tw_consumer_key.')
		print('twitter.lua will not be enabled.')
		return
	elseif not cred_data.tw_consumer_secret then
		print('Missing config value: tw_consumer_secret.')
		print('twitter.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token then
		print('Missing config value: tw_access_token.')
		print('twitter.lua will not be enabled.')
		return
	elseif not cred_data.tw_access_token_secret then
		print('Missing config value: tw_access_token_secret.')
		print('twitter.lua will not be enabled.')
		return
	end
	
	twitter.triggers = {
		'twitter.com/[^/]+/statuse?s?/([0-9]+)',
		'twitter.com/statuse?s?/([0-9]+)'
	}
	twitter.doc = [[*Twitter-Link*: Postet Tweet]]
end

local consumer_key = cred_data.tw_consumer_key
local consumer_secret = cred_data.tw_consumer_secret
local access_token = cred_data.tw_access_token
local access_token_secret = cred_data.tw_access_token_secret

local client = OAuth.new(consumer_key, consumer_secret, {
    RequestToken = "https://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "https://api.twitter.com/oauth/access_token"
}, {
    OAuthToken = access_token,
    OAuthTokenSecret = access_token_secret
})

function twitter:action(msg, config, matches)
  if not matches[2] then
    id = matches[1]
  else
    id = matches[2]
  end

  local twitter_url = "https://api.twitter.com/1.1/statuses/show/" .. id.. ".json"
  local get_params = {tweet_mode = 'extended'}
  local response_code, response_headers, response_status_line, response_body = client:PerformRequest("GET", twitter_url, get_params)
  local response = json.decode(response_body)
  
  local full_name = response.user.name
  local user_name = response.user.screen_name
  if response.user.verified then
    verified = ' ✅'
  else
    verified = ''
  end
  local header = '<b>Tweet von '..full_name..'</b> (<a href="https://twitter.com/'..user_name..'">@' ..user_name..'</a>'..verified..'):'
  local text = response.full_text
  
  -- favorites & retweets
  if response.retweet_count == 0 then
    retweets = ""
  else
    retweets = response.retweet_count..'x retweeted'
  end
  if response.favorite_count == 0 then
    favorites = ""
  else
    favorites = response.favorite_count..'x favorisiert'
  end
  if retweets == "" and favorites ~= "" then
    footer = '<i>'..favorites..'</i>'
  elseif retweets ~= "" and favorites == "" then
    footer = '<i>'..retweets..'</i>'
  elseif retweets ~= "" and favorites ~= "" then
    footer = '<i>'..retweets..' - '..favorites..'</i>'
  else
    footer = ""
  end
  
  -- replace short URLs
  if response.entities.urls then
    for k, v in pairs(response.entities.urls) do 
        local short = v.url
        local long = v.expanded_url
		local long = long:gsub('%%', '%%%%')
        text = text:gsub(short, long)
    end
  end

  -- remove images
  local images = {}
  local videos = {}
  if response.entities.media and response.extended_entities.media then
    for k, v in pairs(response.extended_entities.media) do
        local url = v.url
		if v.video_info then
		  if v.video_info.variants[#v.video_info.variants].bitrate == 2176000 then
		    local vid = v.video_info.variants[#v.video_info.variants].url
			videos[#videos+1] = vid
		  else
		    local vid = v.video_info.variants[1].url
			videos[#videos+1] = vid
		  end
		else
           images[#images+1] = v.media_url_https
        end
        text = text:gsub(url, '')
    end
  end
  
    -- quoted tweet
  if response.quoted_status then
    local quoted_text = response.quoted_status.full_text
	local quoted_name = response.quoted_status.user.name
	local quoted_screen_name = response.quoted_status.user.screen_name
	if response.quoted_status.user.verified then
      quoted_verified = ' ✅'
    else
	  quoted_verified = ''
	end

    -- replace short URLs for quoted tweets
    if response.quoted_status.entities.urls then
      for k, v in pairs(response.quoted_status.entities.urls) do 
        local short = v.url
        local long = v.expanded_url
        local long = long:gsub('%%', '%%%%')
        quoted_text = quoted_text:gsub(short, long)
      end
    end
    
    -- same for media
    if response.quoted_status.entities.media then
      for k, v in pairs(response.quoted_status.entities.media) do
        local short = v.url
        local long = v.media_url_https
        local long = long:gsub('%%', '%%%%')
        quoted_text = quoted_text:gsub(short, long)
      end
    end
    
	quote = '<b>Als Antwort auf '..quoted_name..'</b> (<a href="https://twitter.com/'..quoted_screen_name..'">@' ..quoted_screen_name..'</a>'..quoted_verified..'):\n'..quoted_text
	text = text..'\n\n'..quote..'\n'
  end
  
  -- send the parts 
  utilities.send_reply(msg, header .. "\n" .. utilities.trim(text).."\n"..footer, 'HTML')
  for k, v in pairs(images) do
    local file = download_to_file(v)
	utilities.send_photo(msg.chat.id, file, nil, msg.message_id)
  end
  for k, v in pairs(videos) do
    local file = download_to_file(v)
	utilities.send_video(msg.chat.id, file, nil, msg.message_id)
  end
end

return twitter
