
helpers do
  def require_login
    if session[:id].nil?
      redirect_with_message('/login', 'Please login first')
    elsif Session.first(:uuid => session[:id]).nil?
      session[:id] = nil 
      redirect_with_message('/login', 'Session has expired, please log in again')
    end
  end
  
  def authenticate(email, password)
    response = RestClient.post('https://www.google.com/accounts/ClientLogin', 
                               'accountType' => 'HOSTED_OR_GOOGLE', 
                               'Email'  => email, 
                               'Passwd' => password, 
                               :service => 'xapi', 
                               :source  => 'Goog-Auth-1.0') do |response, request, result, &block|
      
      if response.code == 200
        user = User.first_or_create :name => email
        session[:id] = response.to_s   
        session[:user] = user.id
        return true        
      end
      return false
    end
  end

  def facebook_oauth_authorize
    redirect "https://graph.facebook.com/oauth/authorize?client_id=" +
             FACEBOOK_OAUTH_CLIENT_ID + 
             "&redirect_uri=" + 
             "http://#{env['HTTP_HOST']}/#{FACEBOOK_OAUTH_REDIRECT}"
  end

  def facebook_get_access_token(code)
    oauth_url = "https://graph.facebook.com/oauth/access_token"
      oauth_url << "?client_id=#{FACEBOOK_OAUTH_CLIENT_ID}"
      oauth_url << "&redirect_uri=" + URI.escape("http://#{env['HTTP_HOST']}/#{FACEBOOK_OAUTH_REDIRECT}")
      oauth_url << "&client_secret=#{FACEBOOK_OAUTH_CLIENT_SECRET}"
      oauth_url << "&code=#{URI.escape(code)}"

    response = RestClient.get oauth_url                        
    oauth = {}
    response.split("&").each do |p| ps = p.split("="); oauth[ps[0]] = ps[1] end
    user_object = get_user_from_facebook_with URI.escape(oauth['access_token'])
    user = User.first_or_create :facebook_id => user_object['id']
    user.name = user_object['name']
    user.photo_url = "http://graph.facebook.com/#{user_object['id']}/picture"
    user.chirpy_id = user_object['name'].gsub " ","-"
    user.session = Session.new :uuid => oauth['access_token']
    user.save
    session[:id] = oauth['access_token']
    session[:user] = user.id
    redirect '/'
  end

  def get_user_from_facebook_with(token)
    JSON.parse RestClient.get "https://graph.facebook.com/me?access_token=#{token}"
  end

  def redirect_with_message(to_location, message)
    flash[:message] = message
    redirect to_location
  end
  
  def time_ago_in_words(timestamp)
    minutes = (((Time.now - timestamp).abs)/60).round
    return nil if minutes < 0
    case minutes
    when 0               then 'less than a minute ago'
    when 0..4            then 'less than 5 minutes ago'
    when 5..14           then 'less than 15 minutes ago'
    when 15..29          then 'less than 30 minutes ago'
    when 30..59          then 'more than 30 minutes ago'
    when 60..119         then 'more than 1 hour ago'
    when 120..239        then 'more than 2 hours ago'
    when 240..479        then 'more than 4 hours ago'
    else                 timestamp.strftime('%I:%M %p %d-%b-%Y')
    end
  end  
  
  def snippet(page, options={})
    haml page, options.merge!(:layout => false)
  end  
end