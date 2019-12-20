class MessageCatcher
  def catch arr, text
    arr.each do |word|
      if text.downcase.include? word then
        Proc.new.call word
        break
      end
    end
  end
end
