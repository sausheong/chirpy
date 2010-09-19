require 'uri'
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'mysql://root:root@localhost/chirpy')
class Session
  include DataMapper::Resource
  property :id, Serial
  property :uuid, String, :length => 255
  belongs_to :user

end

class User
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :length => 255
  property :photo_url, String
  property :facebook_id, String
  property :chirpy_id, String
  
  has n, :chirps
  has 1, :session
  
  has n, :follower_relations, 'Friendship', :child_key => [ :source_id ]
  has n, :follows_relations, 'Friendship', :child_key => [ :target_id ]
  has n, :followers, self, :through => :follower_relations, :via => :target
  has n, :follows, self, :through => :follows_relations, :via => :source
      
end

class Friendship
  include DataMapper::Resource
  
  belongs_to :source, 'User', :key => true
  belongs_to :target, 'User', :key => true
end

class Chirp
  include DataMapper::Resource

  property :id, Serial
  property :text, String, :length => 140
  property :created_at, Time

  belongs_to :user

  before :save do
    if starts_with?('follow ')
      process_follow
    else
      process
    end
  end

  # general scrubbing of chirp
  def process
    # process url
    urls = self.text.scan(URL_REGEXP)
    urls.each { |url|
      tiny_url = open("http://tinyurl.com/api-create.php?url=#{url[0]}") {|s| s.read}
      self.text.sub!(url[0], "<a href='#{tiny_url}'>#{tiny_url}</a>")
    }
    # process @
    ats = self.text.scan(AT_REGEXP)
    ats.each { |at| self.text.sub!(at, "<a href='/#{at[2,at.length]}'>#{at}</a>") }
  end

  # process follow commands
  def process_follow
    user = User.first :chirpy_id => self.text.split[1]
    user.followers << self.user
    user.save
    throw :halt # don't save this chirp
  end

  def starts_with?(prefix)
    prefix = prefix.to_s
    self.text[0, prefix.length] == prefix
  end
end

URL_REGEXP = Regexp.new('\b ((https?|telnet|gopher|file|wais|ftp) : [\w/#~:.?+=&%@!\-] +?) (?=[.:?\-] * (?: [^\w/#~:.?+=&%@!\-]| $ ))', Regexp::EXTENDED)
AT_REGEXP = Regexp.new('\s@[\w.@_-]+', Regexp::EXTENDED)
