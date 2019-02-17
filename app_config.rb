module AppConfig
  def self.config
    -> (key) {
      ENV[key]
    }
  end
end
