class Wolfram
  require 'telegram/bot'

  def initialize(input)
    @link = "http://api.wolframalpha.com/v2/query?input=#{input}&appid=#{AppConfig::config['WOLFRAM_APP_KEY']}"
  end

  def get
    unless @link.nil?
      response = Faraday.get @link
      response.body
    end
  end
end
