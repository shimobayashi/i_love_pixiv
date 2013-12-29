require 'nokogiri'

module Utils
  def extract_illust_ids(html)
    doc = Nokogiri::HTML(html)
    doc.search('a.work').map{|e| $1 if e[:href] =~ /illust_id=(\d+)/}
  end
end
