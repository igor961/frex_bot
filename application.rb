require 'telegram/bot'
require 'date'
require 'nokogiri'
require 'csv'
require_relative 'app_config'
require_relative 'wolfram'
require_relative 'firebase_store'
require_relative 'message_catcher'

token = AppConfig::config['TELEGRAM_TOKEN']

db_uri = AppConfig::config['DB_URI']

puts "DB_URI: " << db_uri unless db_uri.nil?

store = FirebaseStore.new db_uri

puts "Token: " << token unless token.nil?
message_catcher = nil

message_catcher = MessageCatcher.new unless AppConfig::config['CATCH'].nil?
puts message_catcher

class String
  def numeric?
    true if Float(self) rescue false
  end
end

def send_photo(field, caption, bot, message)
  unless field.nil?
    begin
      bot.api.send_photo chat_id: message.chat.id, photo: field.attr("src"), caption: caption
    rescue Telegram::Bot::Exceptions::ResponseError => e
      puts e.message
    end
  end
end

def get_field(attr, val, doc)
  doc.at_xpath("//pod[@#{attr}='#{val}']//subpod//img")
end

def get_fields(arr, doc)
  res = {}
  arr.each do |k, v|
    res["#{k}_#{v.downcase}"] = get_field(k, v, doc)
  end
  res
end

def get_path_to_message(str)
  name, category = str.delete(' ').split(':', 2) unless str.nil?
  if category.nil? then	
    Proc.new.call name
  else
    if category.numeric?
      return false
    else
      Proc.new.call "categories/#{category}/#{name}"
    end
  end
  return true
end

def basic_rescue
  begin
    yield	
  rescue Exception => e
    puts e
  end
end

def store_chat_msg(store, chat_id, message_id, sender, content, title, time)
  store.set("all_messages/#{chat_id}/messages/#{message_id}", 
            :content => content, :d_t => time.strftime("%d/%m/%Y %H:%M"), 
            :sender => sender, :timestamp => time)
  store.set "all_messages/#{chat_id}/info/", :title => title
end

Telegram::Bot::Client.run token do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::Message
      unless message.text.nil?
        m_text = message.text
        cur_time = DateTime.now
        cur_time_f = cur_time.strftime("%d/%m/%Y %H:%M")
        igor_arr = %w(игор igor)
        unless message_catcher.nil? then
          message_catcher.catch(igor_arr, m_text) {
            # Any interface
            f_res = store.set("igor_messages/#{message.chat.id}/messages/#{message.message_id}", 
                              :content => m_text, :d_t => cur_time_f, 
                              :sender => message.from.first_name, :timestamp => cur_time)
            store.set "igor_messages/#{message.chat.id}/info/", :title => "#{message.chat.title} - for Igor"
            puts f_res.body
          } 
          store_chat_msg store, message.chat.id, message.message_id, message.from.first_name, m_text, message.chat.title, cur_time 
        end
        #####################################################
        m_arr = m_text.strip.split(' ', 2)
        #puts m_arr
        case m_arr[0]
        when 'pin'
          if !m_arr[1].nil? and (m_arr[1] =~ /[^A-Za-z0-9]/).nil?
            res = get_path_to_message(m_arr[1]) do |str| 
              f_res = store.push("pinned_messages/#{message.chat.id}/#{str}", (message.message_id - 1))
              puts f_res.body
            end
            if res then bot.api.send_message chat_id: message.chat.id, text: "Pinned"
            else bot.api.send_message(chat_id: message.chat.id, 
                                      text: "Please, do not use numeric names of categories")
            end
          end
        when 'get'
          res = get_path_to_message(m_arr[1]) do |str|
            msg_id = store.get("pinned_messages/#{message.chat.id}/#{str}")
            puts msg_id.raw_body
            unless msg_id.body.nil?
              msg_id.body.each do |k, v|
                begin
                  bot.api.forward_message chat_id: message.chat.id, from_chat_id: message.chat.id, message_id: v
                rescue Telegram::Bot::Exceptions::ResponseError => e
                  puts e.message
                  bot.api.send_message chat_id: message.chat.id, text: e.message
                end
              end
            end#end_unless
          end unless m_arr[1].nil?			
        when 'delete'
          get_path_to_message(m_arr[1]) do |str|
            if store.delete "pinned_messages/#{message.chat.id}/#{str}"
              bot.api.send_message chat_id: message.chat.id, text: "OK"
            end
          end unless m_arr[1].nil?
        when 'help'
          help_lines = CSV.read(File.expand_path("../help.csv", __FILE__))
          get_couple = Proc.new {|k, v| "***#{k}*** - _#{v}_"}
          # puts help_lines
          basic_rescue	{		
            bot.api.send_message chat_id: message.chat.id, text: help_lines.map(&get_couple).join("\n\n"), parse_mode: "MARKDOWN" unless help_lines.nil?
          }	
        when 'getcat'
          unless m_arr[1].nil?
            categories = store.get("pinned_messages/#{message.chat.id}/categories") 
            puts categories.raw_body
            get_text = Proc.new {|k, v| "<i>#{k}</i>"}
            basic_rescue {	
              bot.api.send_message chat_id: message.chat.id, text: categories.body.map(&get_text).join("\n"), parse_mode: "HTML"
            }	
          end
        when 'getall'
          all_messages = (m_arr[1].nil?) \
            ? store.get("pinned_messages/#{message.chat.id}/") \
            : store.get("pinned_messages/#{message.chat.id}/categories/#{m_arr[1]}")
          get_text = Proc.new {|k, v| "<i>#{k}</i>" unless k == "categories"}
          puts all_messages.raw_body

          basic_rescue {
            bot.api.send_message chat_id: message.chat.id, text: all_messages.body.map(&get_text).join("\n"), parse_mode: "HTML"
          }
          #		when 'wolfram'
          #			begin
          #				wolfram = Wolfram.new m_arr[1]
          #				res = wolfram.get
          #			rescue Exception => e
          #				puts e
          #			end
          #			doc = Nokogiri::XML(res)
          #			protofields = {
          #				'primary' => 'true',
          #				'title' => 'Plot'
          #			}
          #			fields = get_fields(protofields, doc)
          #			send_photo fields['primary_true'], "Result", bot, message
          #			send_photo fields['title_plot'], "Plot", bot, message
        end
      end
    end
  end
end

