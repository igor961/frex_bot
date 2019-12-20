module AppConfig
  class << self
    def config
      if ENV["ENV"] == "production"
        release_config
      else
        debug_config
      end
    end

    def release_config
      -> (key) {
        ENV[key]
      }
    end

    def debug_config
      -> (key) {
        File.open "var.env" do |file|
          file.each do |line|
            f_key, val = line.split "=", 2
            return val.strip if f_key == key
          end
        end
      }
    end
  end
end
