require 'nokogiri'
require 'cgi'
require 'json'

module Utils
  def extract_illust_ids(html)
    doc = Nokogiri::HTML(html)

    illust_ids = doc.search('[data-items]').map{|e|
      JSON.parse(CGI.unescape(e.attr('data-items'))).map{|illust| illust['illustId'].to_i}
    }.flatten

    # 場所によっては古い情報の持ち方(HTMLべた書き)しているのでこっちも突っ込む
    illust_ids.concat(doc.search('a.work').map{|e| $1.to_i if e[:href] =~ /illust_id=(\d+)/})

    return illust_ids
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
