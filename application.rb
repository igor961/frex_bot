require 'telegram/bot'
require 'firebase'
require 'date'
require 'nokogiri'
require 'csv'
require_relative 'app_config'
require_relative 'wolfram'

token = AppConfig::config["TELEGRAM_TOKEN"]

db_uri = AppConfig::config['DB_URI']

firebase = Firebase::Client.new db_uri

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

Telegram::Bot::Client.run token do |bot|
	bot.listen do |message|
		case message
		when Telegram::Bot::Types::Message
			unless message.text.nil?
				m_text = message.text
				igor_arr = %w(игор igor)
				igor_arr.each {|v|
					if m_text.downcase.include? v then
						puts m_text
						# Any interface
						cur_time = DateTime.now
						f_res = firebase.set("igor_messages/#{message.chat.id}/messages/#{message.message_id}", :content => m_text, :d_t => cur_time.strftime("%d/%m/%Y %H:%M"), :sender => message.from.first_name, :timestamp => cur_time)
						firebase.set "igor_messages/#{message.chat.id}/info/", :title => message.chat.title
						puts f_res.body
						break
					end
				}
				m_arr = m_text.split(' ', 2)
				#puts m_arr
				case m_arr[0]
				when 'pin'
					f_res = firebase.push("pinned_messages/#{message.chat.id}/#{m_arr[1]}", (message.message_id - 1))
					puts f_res.body
					bot.api.send_message chat_id: message.chat.id, text: "Pinned"
				when 'get'
					msg_id = firebase.get("pinned_messages/#{message.chat.id}/#{m_arr[1]}")
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
					end
				when 'delete'
					bot.api.send_message chat_id: message.chat.id, text: "OK" if firebase.delete "pinned_messages/#{message.chat.id}/#{m_arr[1]}"
				when 'help'
					help_lines = CSV.read(File.expand_path("../help.csv", __FILE__))
					get_couple = Proc.new {|k, v| "***#{k}*** - _#{v}_"}
					# puts help_lines
					begin
						bot.api.send_message chat_id: message.chat.id, text: help_lines.map(&get_couple).join("\n\n"), parse_mode: "MARKDOWN" unless help_lines.nil?
					rescue Exception => e
						puts e
					end
				when 'getall'
					all_messages = firebase.get "pinned_messages/#{message.chat.id}"
					get_text = Proc.new {|k, v| "<i>#{k}</i>"}
					puts all_messages.body
					begin
						bot.api.send_message chat_id: message.chat.id, text: all_messages.body.map(&get_text).join("\n"), parse_mode: "HTML"
					rescue Exception => e
						puts e
					end
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
