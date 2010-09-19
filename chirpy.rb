require 'rubygems'
%w(haml sinatra rack-flash json rest_client active_support dm-core).each  { |gem| require gem}
%w(config models helpers).each {|feature| require feature}

set :sessions, true
set :show_exceptions, false
use Rack::Flash

get '/' do
  redirect '/home' if session[:id]  
  redirect '/login'
end

get '/login' do   
  haml :login, :layout => false 
end

get '/login/facebook' do
  facebook_oauth_authorize
end

get "/#{FACEBOOK_OAUTH_REDIRECT}" do
  redirect_with_message '/login', params[:error_reason] if params[:error_reason]
  facebook_get_access_token(params[:code])
end

post '/login' do  
  if authenticate(params[:email], params[:password])
    redirect '/'
  else
    redirect_with_message '/login', 'Email or password wrong. Please try again'
  end
end

get '/logout' do
  @user = User.get session[:user]
  @user.session.destroy
  session.clear
  redirect '/'
end

get '/home' do
  require_login
  @myself = @user = User.get(session[:user])
  @chirps = @user.chirps
  haml :home
end

get '/user/:id' do
  require_login
  @myself = User.get session[:user]
  @user = User.first :chirpy_id => params[:id]
  @chirps = @user.chirps
  haml :home
end

post '/update' do
  require_login
  @user = User.get session[:user]
  @user.chirps.create :text => params[:chirp], :created_at => Time.now
  redirect "/home"
end

get '/follow/:id' do
  require_login
  @myself = User.get session[:user]
  @user = User.first :chirpy_id => params[:id]
  unless @myself == @user or @myself.follows.include? @user
    @myself.follows << @user
    @myself.save
  end
  redirect '/'
end

get '/unfollow/:id' do
  require_login
  @myself = User.get session[:user]
  @user = User.first :chirpy_id => params[:id]
  unless @myself == @user
    if @myself.follows.include? @user
      follows = @myself.follows_relations.first :source => @user
      follows.destroy
    end
  end
  redirect '/'
end

error do  redirect '/' end