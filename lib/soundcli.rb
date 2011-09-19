require "soundcli/settings"
require "soundcli/access_token"
require "soundcli/player"
require "soundcli/track"
require "soundcli/helpers"

class SoundCLI
  public

  def features
    hidden = [:usage, :features]
    return (SoundCLI.public_instance_methods - Object.methods - hidden)
  end

  def usage
    puts "Usage: #{$0} #{self.features.join('|')} [url|query]"
    print <<EOF


EXAMPLES:

   Play a track by URL:
       #{$0} stream http://soundcloud.com/rekado/the-human-song
       #{$0} http://soundcloud.com/rekado/the-human-song

   Play a track by ID:
       #{$0} stream 15966266
       #{$0} 15966266



UNFINISHED STUFF:

   Show my user info:
       #{$0} me

   List my tracks:
       #{$0} me tracks

   List my exclusive tracks:
       #{$0} me activities tracks exclusive

   Search for a user:
       #{$0} search_user fronx
EOF

  end

  def me(args=[])
    self.authenticate || raise("Authentication error")
    params = ["oauth_token=#{@token}"]
    sub = (args.length > 0) ? ('/'+args.join('/')) : ('')
    res = Helpers::get({
      :target => 'me'+sub,
      :ssl    => true,
      :params => params,
      :follow => true
    })
    Helpers::data_pp res[:response]
  end

  def download(args=[])
    self.authenticate || raise("Authentication error")
    Helpers::say("Getting track ID...", :info)
    track_id = Helpers::resolve(args[0])
    Helpers::sayn(track_id, :info)

    unless track_id
      $stderr.puts "Failed to fetch track id."
      return false
    end

    res = Track::info(track_id)
    downloadable = res['downloadable']

    unless downloadable
      $stderr.puts "This track cannot be downloaded."
      return false
    end

    uri = res['download_url']
    return false unless uri

    #TODO: curl this
    params = ["access_token=#{@token}","client_id=#{Settings::CLIENT_ID}"]
    puts uri+'?'+params.join('&')
  end

  # Accepts an address like this:
  #   "http://soundcloud.com/rekado/the-human-song"
  # or a track ID.
  # Gets the actual location and streams it via gstreamer
  def stream(args=[])
    self.authenticate || raise("Authentication error")
    Helpers::say("Getting track ID...", :info)
    track_id = Helpers::resolve(args[0])
    Helpers::sayn(track_id, :info)

    unless track_id
      $stderr.puts "Failed to fetch track id."
      return false
    end

    Helpers::say("Getting stream URI...", :info)
    res = Track::info(track_id)
    streamable = res['streamable']
    unless streamable
      $stderr.puts "This track is not streamable."
      return nil
    end
    stream = res['stream_url']
    return unless stream

    comments = Track::comments([track_id], false)

    begin
      params = ["access_token=#{@token}","client_id=#{Settings::CLIENT_ID}"]
      Helpers::sayn(stream+'?'+params.join('&'), :debug)
      player = Player.new(stream+'?'+params.join('&'), comments)
      player.play
    rescue Interrupt
    ensure
      player.quit if player
    end
  end

  # Accepts a local file and an address like this
  #   "http://soundcloud.com/rekado/the-human-song"
  # or a track ID.
  # Plays the local file and shows soundcloud comments
  def play(args=[])
    self.authenticate || raise("Authentication error")
    if args.length < 2
      $stderr.puts "I need a local file name and a soundcloud address / track ID."
      return false
    end
    location = File.absolute_path(args[0])
    unless File.exists? location
      $stderr.puts "#{args[0]} doesn't seem to be a file."
      return false
    end

    track_id = Helpers::resolve(args[1])
    unless track_id
      $stderr.puts "I could not find this track on soundcloud: #{args[1]}."
      return false
    end

    comments = Track::comments([track_id], false)
    begin
      player = Player.new('file://'+location, comments)
      player.play
    rescue Interrupt
    ensure
      player.quit if player
    end
  end

  def set(args=[])
    self.authenticate || raise("Authentication error")
    # TODO
    set_id = Helpers::resolve(args[0])
    puts set_id
  end

  def search_user(query, limit=5)
    params = ["client_id=#{Settings::CLIENT_ID}",
      "q=#{query}",
      "limit=#{limit}"
    ]
    res = Helpers::get({
      :target => 'users',
      :ssl    => false,
      :params => params,
      :follow => true
    })
    Helpers::data_pp res[:response]
  end

  protected

  def authenticate
    token_data = AccessToken::latest
    token_data = AccessToken::new unless token_data
    AccessToken::refresh if token_data and AccessToken::expired?

    if token_data and token_data.has_key? 'access_token'
      @token = token_data['access_token']
      return true
    else
      $stderr.puts "Could not authenticate."
      return false
    end
  end

end
