require 'nokogiri'

module Utils
  def extract_illust_ids(html)
    doc = Nokogiri::HTML(html)
    doc.search('a.work').map{|e| $1.to_i if e[:href] =~ /illust_id=(\d+)/}
  end

  def extract_member_ids(html)
    doc = Nokogiri::HTML(html)
    doc.search('a.user').map{|e| $1.to_i if e[:href] =~ /id=(\d+)/}
  end

  def log_multi_stat(multi)
    multi.responses[:errback].values.each {|conn|
      p conn.error
    }

    callback_length = multi.responses[:callback].length
    errback_length = multi.responses[:errback].length
    puts "callback: #{callback_length}, errback: #{errback_length}, total: #{callback_length + errback_length}"
  end
end
